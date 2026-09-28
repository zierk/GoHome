# GoHome

**GoHome** is a Windower 4 addon for Final Fantasy XI that helps automate returning your character to their home nation's Mog House.

The addon uses the **Port San d'Oria**, **Port Bastok**, or **Port Windurst** Home Point closest to the Mog House, depending on your character's nation. After warping, GoHome automatically walks your character from the Home Point into the Mog House.

## Requirements

- [Windower 4](https://www.windower.net/)
- **Superwarp** addon
- The corresponding Home Point in your character's home nation must be unlocked.
- The command must be executed while your character is within **5 yalms of any Home Point**.

## Usage

Load the addon:

    //lua load gohome

Start GoHome:

    //gohome start

or:

    //gh start

GoHome will determine your character's nation, use Superwarp to travel to the appropriate Home Point, and automatically walk your character into the Mog House.

To stop the addon while it is moving your character:

    //gohome stop


## Note from the Author:
I made this addon mainly because I'm lazy and didn't feel like piloting all of my characters to their home nation when I needed to get them to do gardening for Deeds. Not all of my characters are the same nation so this was a lightweight solution.