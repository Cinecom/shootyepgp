# shootyepgp
Guild Helper addon for EPGP loot system in WoW (1.12)

## setup
shootyepgp requires some modifications to guild permissions for officer notes by the guild leader.  

### Version 3.x (current)
- officer notes must be set to visible by all and editable **only** by the EPGP admins (eg. officer rank+)
- public notes are free to be used for anything

### _Version 2.x (deprecated)_ 
- _public and officer notes must be set to visible by all._
- _both public and officer notes **must** be editable **only** by the EPGP admins (eg. officer rank+)_

## tips
Creating a new chatframe (right-click > create new window on chat tab) and naming it `debug` (capitalization doesn't matter) will move the bulk of information messages there and out of your default chatframe.

## usage
Right-click on minimap or FuBar shootyepgp icon show all available settings.  
Left-click shows the standings window with everyone's EP, GP and PR values. 
The standings window can also be used to toggled with **/shooty** chat command 

## features
- EPGP standings list (all)
- Simple chatlink click to bid on items (all)
- Item Bids list (admin/ML)
- Item GP prices on item tooltips (all)
- Export standings to cvs (all)
- Configurable EPGP Decay (admin)
- Configurable Offspec discount (all)
- Guild Progression multiplier (all)
- Reserves - *standby list EP* - with alts support (admin and all)

Addon has been designed so that the main member functionality is available even without the addon. 
- `/w masterlooter +` (for main spec) or `/w masterlooter -` (for off spec) after the loot officer links a piece of loot and asks for bids in raid chat.  
- Type `/x +` (where x is the number of the custom channel) or `/x +MainName` if on an alt to respond to a standby list afk check.  
Having the addon makes everything more convenient, but is not mandatory.

## epgp basics and help
[shootyepgp wiki](https://github.com/Road-block/shootyepgp/wiki)

## download
- Release version: Download shootyepgp-x.y-11200.zip file from [latest](https://github.com/Road-block/shootyepgp/releases/latest) and extract to AddOns folder.
- *Alpha version: Download shootyepgp-master.zip from [here](https://github.com/Road-block/shootyepgp/archive/master.zip) extract to AddOns folder and **remove** the -master suffix from the folder so it's just `shootyepgp`.*
