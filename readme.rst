
Total DOS Launcher
##################

The Total DOS Launcher is a system for easily loading and running thousands of
DOS programs on vintage hardware.

If you're familiar with vintage gaming console "flash multicarts" that load
hundreds of games onto a single console, that's what this is.
Think of this project as "console multicart" software for DOS.

.. contents::
.. section-numbering::


Introduction
============

The Total DOS Launcher (TDL) was created for people who want to load their
vintage systems with tons of programs and have them easily searchable and
launchable without having to configure any menus by hand.  In a nutshell, the
TDL takes vintage archives on your modern system:

| A Mind Forever Voyaging r77 (1985)(Infocom, Inc.) [Adventure, Interactive Fiction].zip
| Adventure (1987)(Willie Crowther, Kevin B. Black) [Adventure, Interactive Fiction].zip
| Adventure in Serenia [DC] (1982)(IBM) [Adventure, Interactive Fiction].zip
| Adventures of Buckaroo Banzai Across the Eighth Dimension, The v3.87 (1985)(Adventure International) [Adventure, Interactive Fiction].zip
| Alley Cat [DC] (1984)(IBM) [Action].zip
| Archon- The Light and the Dark [DC] (1984)(Electronic Arts, Inc.) [Action, Strategy].zip
| Arcticfox (1986)(Electronic Arts, Inc.) [Action, Simulation].zip
| Battlezone [DC] (1983)(Atarisoft) [Action, Simulation].zip
| Borrowed Time [DC] (1985)(Activision, Inc.) [Adventure].img.zip
| Bouncy Bee Learns Letters v1.01 (1985)(IBM) [Educational].zip
| California Games v1.01 (1988)(Epyx, Inc.) [Sports].zip
| Centipede [DC] (1983)(Atarisoft) [Action].zip
| Chessmaster 2000, The (1986)(Software Toolworks, Inc., The) [Strategy, Chess].zip
.

...and copies them to a temporary directory using DOS-compatible filenames that
can be copied over to any DOS system, even 16-bit DOS versions without
long-filename support::

 AMINDFOR.ZIP
 ADVENTUR.ZIP
 ADVENTUA.ZIP
 ADVENTUB.ZIP
 ALLEYCAT.ZIP
 ARCHON-T.ZIP
 ARCTICFO.ZIP
 BATTLEZO.ZIP
 BORROWED.ZIP
 BOUNCYBE.ZIP
 CALIFORN.ZIP
 CENTIPED.ZIP
 CHESSMAS.ZIP

...along with a menu program that easily launches them without requiring
them to be unzipped beforehand:

.. image:: docs/menu_example.png
   :alt: A sample TDL menu
   :align: center

It can do this with a few hundred programs, or thousands, or *tens of
thousands* -- the only limitation is how much addressable storage space you have on
your target DOS system.

The DOS-based launcher currently has the following features:

- Automatically decompresses archive files if necessary
- Creates bootable diskettes from bootable disk image files
- Uses less than 300 bytes of RAM to launch programs (smaller than a single CONFIG.SYS BUFFER)
- Caches itself to EMS, XMS, or raw extended memory to make returning to the menu instantaneous after a launched program exits
- Runs on any system (8088 or higher, MDA or better)
- Supports any text mode, from 40x25 up to 132x60
- Can mark/unmark titles as "favorites" and toggle the display between all programs and only favorites

The TDL is currently in alpha development and testing;
this paragraph will be removed when it is ready for prime time.  If you run into trouble testing the TDL, feel free to `contribute an issue via the github
project. <https://github.com/MobyGamer/total-dos-launcher/issues>`_
Features planned for the near future include search-as-you-type filtering of the game list, automatic management of the game cache, and customizable color schemes.



Using TDL
=========

Overview
--------

The Total DOS Launcher consists of two programs:  An indexer, and a menu
system.  You use the indexer to prepare your files for copying over to
the vintage DOS system, and you use the menu program on the DOS system
to navigate and launch the programs you copied over.

Where to download
^^^^^^^^^^^^^^^^^
For those not familiar with how github works, you can grab the most recent release from this repository's releases tab: https://github.com/MobyGamer/total-dos-launcher/releases


Prerequisites
-------------

Indexer:
  Currently a python script, so you'll need to install python 3.6 or
  higher on your system if it isn't already there.  (When this project is
  past the beta stage, native binaries will be provided for Windows, Mac,
  and Linux.)

Menu program:
  The menu program runs on any IBM PC or 100% compatible running DOS 2.10
  or higher, with 384 KB RAM or higher.  (If EMS or XMS are available, they
  are automatically used to speed operation.)

Step One: The Indexer
---------------------

To prepare your files for copying over, run TDLIndexer.py with these arguments:

.. code-block:: bash

  TDLIndexer.py <source directory> <destination directory>

The TDLIndexer.py program *MUST* be run in the same directory that
contains the ``distro`` subdirectory, which contains all of the menu
program elements that will get copied over with your files.



Example Usage (in this case, from a Window system)::

 C:\Projects\TDL>TDLindexer.py ..\dos_program_sources\small.generic.4example output
 Gathering list of files...
 Found 96 files to copy.
 Converting to DOS-friendly 8.3 filenames...
 Generating files index...
 Generating titles index...
 Copying files from ..\dos_program_sources\small.generic.4example to output ...
 Done.

This results in a complete distribution ready to copy over to your DOS system.  It consists of the menu program, some index files, and your original source files in a ``files`` subdirectory::

 02/03/2018  11:17 PM    <DIR>          files
 01/18/2018  11:00 PM    <DIR>          utils
 01/20/2018  06:22 PM           139,712 TDL.EXE
 02/03/2018  11:17 PM             8,481 TITLES.IDX
 02/03/2018  11:17 PM             1,346 FILES.IDX
 07/07/2017  03:36 PM             2,988 TDL.INI
 07/07/2017  03:36 PM             4,169 HANDLERS.INI


The indexer recurses through subdirectories.  So if your menu structure
looks like this::

 DOS Games\
   Adventure\
     1981\
     1982\
     1983\

...they will all get picked up by the indexer as long as you specify
``DOS Games`` as the source directory.

Acceptable File Types
^^^^^^^^^^^^^^^^^^^^^

Each program you want to process with the TDL must be self-contained in a single file.  This typically means that all files that make up a single program (.EXE files, data files, etc.) be contained in a .zip file.  However, you can process individual .COM and .EXE files as long as they don't require additional files.  For example, the freeware game Flightmare (1984) only came as a single ``FLIGHT.COM`` file; it doesn't require any other files to run, so you can feed ``FLIGHT.COM`` directly to TDL without first putting it in a .zip file.

You can also feed non-program files to TDL, such as .TXT text files, GIFs, whatever.  They'll be copied over as well, and if the appropriate handler exists on the target system, it will be used to "launch" those files as well.  (See "Handling additional file types" elsewhere in this documentation.)

Step Two: Copy to the vintage system
------------------------------------

Using any method you feel comfortable with, copy the entire contents of
the output directory you specified over to your vintage DOS system,
being careful to preserve the directory structure.

Instructing the user on copying files from a modern system to a vintage
system is beyond the scope of this documentation, but here are a few
pointers to get you started:

- **Removable hard drives:**  You can use a Compact Flash card instead of a
  physical IDE drive with a cheap CF-to-IDE adapter; then all you need to
  do is insert it into your modern system with a CF card reader to do the
  copy.  For very old systems that can't use IDE drives, there are
  homebrew ISA hard drive adapters that use CF cards directly; search the
  internet for "XTIDE Compact Flash" to find a few examples.

- **TCP/IP:** Install a network card that has a supported DOS packet driver,
  then install and use some sort of transport to copy the files over.
  This can be Microsoft LAN Manager, Novel Netware, etc., or a simpler and
  faster option like Mike Brutman's mTCP suite.  If your system can load
  programs into upper memory, you can also get away with running MS LANMAN
  resident, and just access your files as a driver letter over the
  network.

- **CD or DVD:** Burn everything to a CD or DVD and just run from there.

While a serial or parallel cable can also work to copy files over (like
LapLink, FastLynx, INTERLNK/INTERSVR, etc), the speed of a serial or
parallel cable is extremely slow compared to the above methods and is
generally not recommended unless you have no other choice.


Step three: Launch the menu program
-----------------------------------

On your vintage system, navigate to the directory you copied over and type ``TDL`` to launch the menu.
Once the menu appears, use the arrow keys to navigate to the software you want to launch, and hit
enter.  The software will then run, and when it exits, you'll be returned to
the menu to make another selection.

If the software you copy over is in compressed archives (ie. .ZIP files), the
menu is smart enough to decompress an archive into a cache directory before
trying to launch it.  (It is also smart enough to *not* decompress an archive if
it already exists in the cache.)

Additional Features
^^^^^^^^^^^^^^^^^^^

The TDL has some additional features that help with navigation and execution:

- Pressing any letter will jump to the first title starting with that letter
- Pressing ``F2`` will mark/unmark a title as a "favorite", and you can use ``CTRL-F`` to toggle the title display between all titles and only favorites

Press ``F1`` while in TDL to display a complete list of keys and functions.

The TDL swaps itself out of low DOS RAM before a program needs to run, and restores itself after the program has finished executing.  By use of this swapping mechanism, the TDL does not "steal" any low DOS RAM away from programs that need to run.

The TDL has been successfully tested with 32-bit protected-mode programs that require a DOS extender (such as ``DOS4GW``).


Configuring TDL
===============

*TDL, out of the box, does not need to be configured.*  If you want to
configure it to your liking, such as specifying multiple source
directories (to get past the DOS 2G partition limit), forcing a specific
location for the cache directory, using a high-res VESA text mode, etc.
then edit the ``TDL.INI`` and ``HANDLERS.INI`` files.  Both .INI files
contain a description of what they do.

``TDL.EXE`` also has some command-line options to control how it operates:

/h      Print a summary the most current set of command-line
        options.
/c      Set 43-line (EGA) or 50-line (VGA) mode.  (If you need more
        lines than that, see TDL.INI for VESA options.)
/r      Instructs TDL that it resides on read-only media (ie. CDROM or
        DVDROM) and that it should not try to write anything to its local
        filesystem.  This disables "favorites" as well as writing the debug
        log to disk.
/d      Print excessive debugging messages during initialization.
        Used for troubleshooting only.
/f      Always use fast display routines on all CGA systems.  This
        may cause "snow" or display corruption on true CGA adapters.

Handling Additional File Types
-----------------------------

TDL uses a "handlers" system to determine what to do with a file when the user
requests lauching it.  When a file is selected, TDL looks in HANDLERS.INI to
determine what should be done with that particular file.

You probably won't need to touch HANDLERS.INI.  Out of the box, it is
configured to do the following:

- Launch .EXE or .COM files
- Decompress .ZIP and .ARC files, and launch programs inside them
- Run BASIC .BAS files with GWBASIC or BASICA
- Write raw image formats (.360, .720, etc.) to a blank floppy in drive A:
- Display .TXT and .NFO files

If you'd like to configure TDL to handle something less common, such as
decompressing uncommon file types (.ARJ, etc.), viewing pictures, etc., then
you'll need to add their file extensions and associated utility programs to
HANDLERS.INI.  Consult HANDLERS.INI itself for documentation.

Contributing to the TDL
=======================

The author welcomes contributions and enhancements, especially in the form of the python indexer.
Quick cheat-sheet for those who have never contributed to a github open-source project before:

1. Fork it!
2. Create your feature branch: git checkout -b my-new-feature
3. Commit your changes: git commit -am 'Add some feature'
4. Push to the branch: git push origin my-new-feature
5. Submit a pull request

This guide may be helpful: https://akrabat.com/the-beginners-guide-to-contributing-to-a-github-project/

Design Requirements For New Features
------------------------------------

The following constraints are in place:

- Any python code must be 3.x, as the indexer already uses some 3.6+ features.
- The DOS launcher must be able to run on an 8088 system with MDA or better video

If your new feature is optional and won't break the above constraints (for example, you want to add mouse support to the DOS launcher), that's fine.  Any pull request that **breaks** the above constraints will not be accepted.

If you want to add a feature that breaks compatibility with older systems, check with me before working on it, as there is likely a way to implement what you want while still staying compatible with the 8088.


Building TDL
------------

*Building the TDL is not required to use it!*  This section is only for
those who want to hack on the code and contribute back to the project --
however, be prepared to get (re)acquainted with DOS compilers and tools!


Languages
^^^^^^^^^
TDL is written in Turbo Pascal 7.0, with a small amount of assembler
thrown in for speed or utility.  Knowledge of Pascal is required to
extend TDL.  Knowledge of assembler is helpful, but not required.

Libraries
^^^^^^^^^
TDL is not 100% self-contained; it uses some support libraries and units
to provide functionality like CUI/TUI primitives, userspace swapping,
and stream extensions.  Ensure you have both
https://github.com/MobyGamer/TPLibs and
https://github.com/MobyGamer/UNITS available in your source path.

Compilers and Tools
^^^^^^^^^^^^^^^^^^^
Borland Pascal 7.0, which includes both Turbo Pascal as well as Turbo
Assembler/linker/debugger, is available via your favorite search engine.
A full installation of it is rumored to be included in
ftp://ftp.oldskool.org/pub/misc/xtfiles.rar but this is unconfirmed.

Compiler/Assembler restrictions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
You must always ensure that the code you write will execute on any x86
system, including the 8088.  Don't use 80186+ instructions such as
``PUSHA``, ``POPA``, ``ENTER``, ``LEAVE``, etc.  In Turbo Pascal, always
ensure ``$G-,N-,E-`` to turn off 80286 code generation, 8087 code
generation, and 8087 emulation respectively.  One of TDL's design goals
is the ability to work on any IBM PC or compatible.



Frequently-Asked Questions
==========================


Usage
-----

*Can I use this with emulators such as DOSBox?*  Yes, but if you are
using an emulator, there are much better launchers and front-ends you
can use, such as
`Metropolis Launcher <https://metropolis-launcher.net/>`_ .
TDL was developed to solve issues specific to running large archives of
software directly on vintage computers, and as such, doesn't have as many
features as modern emulator front-ends.

*Where can I find collections of DOS games to run on my vintage system?*
Any internet search can help you.  As of this writing, "DOS game collection"
produced 3.2 million hits in google.  If you'd like to support commercial
entities that legally sell vintage games, some choice exists, with
`Good Old Games <http://www.gog.com/>` being the most popular as of 2018.

Extending the code
------------------

*Why was this written in Pascal and assembler, instead of something more
popular like C?*
The principle developer of the TDL prefers the Turbo Pascal 7 IDE when writing code on, and for, 8088-based systems.
The TP7 IDE is a powerful
development environment that allows an 8088-based IBM PC
with 640KB to perform symbolic debugging with conditional breakpoints,
watch/inspect/change variables at runtime, and watch CPU registers change line
by line, all without leaving the IDE.  Also, TP7 makes it easy to speed up
sections by either writing in-line assembler directly in the pascal source, or
linking to external assembler objects (which can also be traced and debugged
within the IDE, with the same features previously listed).

*Turbo Pascal 7 isn't free; will you switch to FreePascal at some point?*
The formal commit of 8086 code generation in FreePascal in 2017 now makes this
possible, so it is conceivable the project will move to FreePascal once all
proposed features have been added and the codebase is frozen.


Philosophy
----------

*Emulators are much easier to use than maintaining original hardware.  Why not just use emulators?*
Both hardware and emulators are useful for running programs for which the
hardware environments are no longer sold or maintained.  Emulators are
unparalleled for their accessibility.  But, as good as emulators are,
the only way to truly research a historical work is to experience
it on the hardware that work targeted.

Additional INI options in BBond007 "MiSTer" version fork:  
---------------------------------------------------------

;Change favorite ico - default heart=3h

favicon=21

;Set the colors for TDL's Menu:

COLOR_Border=9fh
 
COLOR_Title=0fh
 
COLOR_Icon=7fh
 
COLOR_HiHot=9fh
 
COLOR_HiNorm=f9h
 
COLOR_LoHot=9ah
 
COLOR_LoNorm=9fh
 
COLOR_Off=9fh
 
COLOR_Win_Border=70h
 
COLOR_Win_Body=9fh

COLOR_Win_Icon=9fh
 
COLOR_Win_Title=0fh
 
COLOR_Fav_Icon=94h
 
COLOR_UNP_Icon=98h

;DisableBlink -- turn off blinking characters for 8 additional background colors
 
DisableBlink=FALSE

;COLOR_MiSTer_Turbo defines background color for Slow/Medium/Fast
 
COLOR_MiSTer_Turbo=9fh
 
COLOR_MiSTer_Slow=92h 
 
COLOR_MiSter_Medium=9eh
 
COLOR_MiSter_Fast=9ch

;Disable the Turbo option in TDL, F3 to hot cycle through Turbo option 
 
MiSTerTurbo=TRUE

;Sort Field -- Dos/Name/Ext/Size/Time
 
istSortField=Name

;Sort Order -- Ascending = True, Descending = False
 
ListSortAscend=TRUE

;Turn on joystick control in TDL
 
joystick=true

;Optional Joystick Axis settings, leave undefined for autodetect
 
;JoyAxisACentMin=64h
 
;JoyAxisACentMax=2bch
 
;JoyAxisBCentMin=64h
 
;JoyAxisBCentMax=2bch
 
;Mouse options, some Char examples - 12h, 09h, default 02h
 
Color_Mouse=$4fh
  
MouseChar=02h
