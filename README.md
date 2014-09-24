BlockIO-LSL
===========

A LSL script for Dogecoin transactions using http://Block.io

Ready for use in vendor systems, uses link messages to communicate with other scripts.  See the test file for clues on how the API works.

Works with vanilla Opensimulator/SL/Whitecore.

Requires a notecard named BlockIO_Config in the object's inventory.  This contains the API key for the seller's Block.io account (seller will need a Block.io account).  Probably a good idea to lock that cards permissions down.


Compatible Scripts:
============
* SimpleBlockIOVendor: https://github.com/AlanTupper/SimpleBlockIOVendor

Coming Soon:
============
* API documentation
* Tutorial on setup and use
* Improvements to allow for multiple currencies without configuration
* Better configuration options (fast vs. safe confirmation, inworld QR code loading)
* Example scripts for tip-bots, etc.

