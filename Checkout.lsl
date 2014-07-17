string api_key = "";

string base_wallet_url = "https://dogeapi.com/wow/v2/?api_key=";
// DogeAPI is slow as molasses when it comes to txn confirmations.  Using Dogechain is slightly less safe, but much more user friendly.
string base_confirm_url = "http://dogechain.info/chain/Dogecoin/q/addressbalance/";
// Google Charts is used for generating QR codes becuase it's fast and easy.
string base_qr_url = "http://chart.apis.google.com/chart?cht=qr&chs=300x300&chl=";

string payment_address;
float purchase_amount = 0.0;
key payer;
key curr_req;
integer sender;

// a very hacky universal way of getting around the lack of default JSON functions in OS.
//strips all the formatting from a json string and filters out specified unwanted elements.
list strip_json(string json, list filter)
{
    list full_filter = ["\"",":","{","}"] + filter;
    list elements = llParseString2List(json,full_filter,[]);
    
    return elements;        
}

//parse a payment address from a get_new_address call;
string parse_address(string body_json)
{
    string address = "";

    list elements = strip_json(body_json,["data","address"]); 
    if(llGetListLength(elements) == 1){ address = llList2String(elements,0); }
    
    return address;
}

//Load a generated QR code that uses the payment protocol
load_qr()
{
    
    string payment_uri = "dogecoin:" + payment_address + "?amount=" + (string)purchase_amount;
    string url = base_qr_url + payment_uri;
    string message = "Scan this QR code with your Dogecoin wallet to get the payment information in a snap.";

    llLoadURL(payer,message,url);   
}

//Complete the Transaction
complete_transaction(integer success)
{
    if(success){ llSay(0,"Transaction Complete! Thanks for using Dogecoin!"); }
    else{ llSay(0, "Transaction Failed. Sorry about that!"); }
    
    llMessageLinked(sender,success,"COMPLETE",payer);
}

default
{   
    on_rez(integer n)
    {
        llResetScript();    
    }
    
    state_entry()
    {
        llSetText("",<1.0,1.0,1.0>,0.0);
        
        //load from config if we're coming from a hard reset.
        if(api_key == ""){state initialize;}  
          
        //set default values in case we're coming back from a successful transaction.
        payer = NULL_KEY;
        curr_req = NULL_KEY;
        payment_address = "";
        purchase_amount = 0.0;       
    }
    
    link_message(integer origin, integer amount, string command, key id)
    {
        if(command == "CHECKOUT")
        {
            payer = id;
            purchase_amount = (float)amount;
            sender = origin;
            
            state fetch_address;
        }   
    }

}

state fetch_address
{
    state_entry()
    {  
        llMessageLinked(sender,0,"WORKING",payer);
        llSay(0, "Fetching a payment address...");
        string url = base_wallet_url + api_key + "&a=get_new_address";
        curr_req = llHTTPRequest(url,[],"");   
    }
    
    http_response(key req, integer status, list meta, string body)
    {
        if(req == curr_req)
        {
            if(status == 200)
            {
                payment_address = parse_address(body);
                
                state request_payment;
            }
            else
            {
                llSay(0,"Got Error Code " + (string)status);
                state error;   
            }      
        }
    }
}

state request_payment
{
    state_entry()
    {
        string pay_msg = "Please send " +  (string)purchase_amount + " to " + payment_address + "\n" +
            "Touch to confirm payment\n" + 
            "Say \"QR\" for a payment QR code";
        string label = "Waiting for payment input";
                
        llSetText(label,<1.0,1.0,1.0>,1.0);
        llSay(0,pay_msg);
        llListen(0,"",payer,"");
    }
    
    listen(integer c, string name, key k, string msg)
    {
        msg = llToUpper(msg);
        if(msg == "QR"){load_qr();}
    }
    
    touch_start(integer n)
    {
        if(llDetectedKey(0) == payer){ state confirm_transaction; }   
    }        
}

state confirm_transaction
{
    state_entry()
    {
        string label = "Confirming Payment, please wait...";
        llSetText(label,<1.0,1.0,1.0>,1.0);
                
        llSetTimerEvent(10.0);    
    }

    
    timer()
    {
        string url = base_confirm_url + payment_address;
        curr_req = llHTTPRequest(url,[],"");  
    }
    
    http_response(key req, integer status, list meta, string body)
    {
        if(req == curr_req)
        {
            if(status == 200)
            {
               /* if(purchase_amount <= parse_amount_recieved(body))
                {
                    llSetTimerEvent(0.0);
                    complete_transaction(); 
                }*/
                float amount = llList2Float(llParseString2List(body,[],[]),0);
                
                if(amount >= purchase_amount)
                {
                    llSetTimerEvent(0.0);
                    complete_transaction(TRUE);
                    state default; 
                }
            }
            else
            {
                llSay(0,"Got Error Code " + (string)status);   
            }      
        }
    }

}

state initialize
{
    state_entry()
    {
        llSetText("Initializing",<1.0,1.0,1.0>,1.0);
        curr_req = llGetNotecardLine("DogeAPI_Config",0);   
    }
    
    dataserver(key req, string data)
    {
        if(curr_req == req && data != EOF)
        {   
            list params = llParseString2List(data,[":"],[]);
            if( llList2String(params,0) == "api_key" )
            { 
                api_key = llList2String(params,1);
                llOwnerSay("Successfully loaded config file"); 
                state default;    
            }
            else { llOwnerSay( "Error reading config file" ); }
        }        
    }
    
    changed(integer change)
    {
        // blindly retry reading the config if the inventory changes.
        if(change & CHANGED_INVENTORY){ curr_req = llGetNotecardLine("DogeAPI_Config",0); }    
    }    
}

state error
{
    state_entry()
    {
        llSay(0,"Checkout System encountered an error.  Restarting.");
        complete_transaction(FALSE);
        llResetScript();   
    }
}
