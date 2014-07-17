default
{
    state_entry(){}    
        
    touch_start(integer n)
    {
        llMessageLinked(LINK_SET,150,"CHECKOUT",llDetectedKey(0));
        llSay(0,"Sending message to Checkout Script");    
    }
    
    link_message(integer origin, integer status, string msg, key id)
    {
        if(msg == "WORKING")
        {
            llSay(0, "Checking out " + llKey2Name(id));    
            state waiting;
        }    
    }
}


state waiting
{

    link_message(integer origin, integer status, string msg, key id)
    {
        if(msg == "COMPLETE" && status == TRUE)
        {
            llSay(0, llKey2Name(id) + " successfully checked out using Dogecoin! Much Excite!");
            state default;    
        }    
    }    
    
}
