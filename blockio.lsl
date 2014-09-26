string api_key = "";

string base_wallet_url = "https://block.io/api/v1/";
// Google Charts is used for generating QR codes becuase it's fast and easy.
string base_qr_url = "http://chart.apis.google.com/chart?cht=qr&chs=300x300&chl=";

string payment_address;
float purchase_amount = 0.0;
integer fast_confirm = TRUE;
key payer;
key curr_req;
integer sender;

// a very hacky universal way of getting around the lack of default JSON functions in OS.
//strips all the formatting from a json string and filters out specified unwanted elements.
list strip_json(string json, list filter)
{
    list full_filter = ["\"",":","{","}"," ","\n",","] + filter;
    list elements = llParseString2List(json,full_filter,[]);
    
    return elements;        
}

//parse a payment address from a get_new_address call;
string parse_address(string body_json)
{
    string address = "";

    list elements = strip_json(body_json,[]); 
    integer index = llListFindList(elements,["address"]);
    if(index >= 0){ address = llList2String(elements,index+1); }
    
    return address;
}

float parse_amount(string body_json)
{
    float amount = 0.0;
    
    list elements = strip_json(body_json,[]);
    
    string selector = "";
    
    if(fast_confirm){ selector = "unconfirmed_received_balance"; }
    else{ selector = "available_balance"; }
    
    integer index = llListFindList(elements,[selector]);
    
    if(index >= 0){ amount = llList2Float(elements,index+1); }
    
    return amount;
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

string build_fetch_url()
{
    string url = base_wallet_url + "get_new_address/?api_key=" + api_key;
    return url; 
}

string build_confirm_url()
{
    string url = base_wallet_url + "get_address_balance/?api_key=" 
                + api_key + "&address=" + payment_address;
    return url;
}


default
{   
    on_rez(integer n)
    {
        llResetScript();    
    }
    
    state_entry()
    {
        
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
            
            if(purchase_amount == 0.0)
            {
                complete_transaction(TRUE);
                state default;
            } 
            else {state fetch_address;}
        }   
    }

}

state fetch_address
{
    state_entry()
    {  
        llMessageLinked(sender,0,"WORKING",payer);
        llSay(0, "Fetching a payment address...");
        string url = build_fetch_url();
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
            "Say \"QR\" for a payment QR code \n" +
            "or \"CANCEL\" to cancel transaction";
            
        llSay(0,pay_msg);
        llListen(0,"",payer,"");
    }
    
    listen(integer c, string name, key k, string msg)
    {
        msg = llToUpper(msg);
        if(msg == "QR"){load_qr();}else
        if(msg == "CANCEL")
        {
            complete_transaction(FALSE);
            state default;
        }
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
        string confirm_msg = "Confirming Payment, please wait...";
        llSay(0,confirm_msg);
                
        llSetTimerEvent(10.0);    
    }

    
    timer()
    {
        string url = build_confirm_url();
        curr_req = llHTTPRequest(url,[],"");  
    }
    
    http_response(key req, integer status, list meta, string body)
    {
        if(req == curr_req)
        {
            if(status == 200)
            {
                float amount = parse_amount(body);
                
                if(amount >= purchase_amount)
                {
                    llSetTimerEvent(0.0);
                    complete_transaction(TRUE);
                    state default; 
                }
            }
            else
            {
                llOwnerSay("Got Error Code " + (string)status);   
            }      
        }
    }

}

state initialize
{
    state_entry()
    {
        llOwnerSay("Initializing");
        curr_req = llGetNotecardLine("BlockIO_Config",0);   
    }
    
    dataserver(key req, string data)
    {
        if(curr_req == req && data != EOF)
        {   
            list params = llParseString2List(data,[":"],[]);
            if( llList2String(params,0) == "api_key" )
            { 
                api_key = llList2String(params,1);
                llOwnerSay("Successfully loaded BlockIO config file"); 
                state default;    
            }
            else { llOwnerSay( "Error reading BlockIO config file" ); }
        }        
    }
    
    changed(integer change)
    {
        // blindly retry reading the config if the inventory changes.
        if(change & CHANGED_INVENTORY){ curr_req = llGetNotecardLine("BlockIO_Config",0); }    
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
