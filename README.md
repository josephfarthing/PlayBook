# About this fork

I really wanted to read a lot with this app, so these are all the things I needed to do for that to be possible. 

The starting point for me was that I have less than perfect eyesight and I really wanted to add a larger font size. Then I realised that after I hacked in larger fonts that only half of each line was visible - because the line breaks were not accurately taking kerning into account.

One thing led to another and I ended up with a lot of changes in the code.

### Features:
- Added larger font support, and more accurate line breaking (the original didn't take kerning into account, which is a problem for larger fonts)
- New navigation buttons - A/B goes page forward/back (like a Kindle), crank and up/down arrows still work, I disabled left/right because I needed the buttons for other things
	- I added this because constantly scrolling is a pretty good way to get eye strain and burn through battery faster
- Hold B to bookmark a page
	- The bookmarks are saved with the time they are created and what % through the book
- Access chapters bookmarks and settings from the pause menu
	- Frees up the A/B buttons for page turning
- Pause menu also has progress info (% and time remaining) for the current book
	- For a huge book the scroll bar is a bit imprecise, and I usually browse without it to fit as much (big) text on the screen as possible
- Added folder support (left/right from main screen, hold A to lift a book out of the stack, then left right to move it, and press A again to put it back down)
	- I imagine the user having a couple of folders of books they want to read on a trip, for example
	- Folders are capped at 5 total
	- There is an "in progress" folder to the left of the main screen that only shows books you started reading

### Quality of life:
- Menu starts from the first book not the last (A-Z)
- App re-opens in the last book you read at the place you left it
- The library menu loads much faster when you have a lot of books on the device
	- I had to give up on the long scroll of books, it was taking 5 minutes to get to the first book

### Efficiency:
- Reduce screen draws and reduce refresh rate to 10hz when idle

### Prebaked txt format:
- .pdb (PlaydateBook) text files can be made with a python script that pre-bakes potential hyphenation positions into the file and add chapter markers
- When viewing a PDB file you can navigate to chapters from the navigation option in the pause menu

### Important notes:

I used an LLM to code quite a lot of the modifications, though I have checked the code by hand as much as possible. The pixel art was modified or made directly by my own hand without any AI.  I make no ethical claim to be a developer of this app, as Lua is a language I only vaguely know and all the credit for this project goes to Idrees. I made the modifications entirely so that I could enjoy books on my Playdate and I'm happy if it helps someone else.

If you enjoy this fork, I strongly encourage you to purchase the original PlayBook app on the Catalogue or otherwise support the original developer.

The original readme is below:

----------------------
# PlayBook
## A powerful and flexible ebook reader for the Playdate console


![web_side_1600x480](https://github.com/IdreesInc/PlayBook/assets/4875804/07ec9ff4-bc34-4d29-b20b-30b8cbf5f2ec)

## **[Get it here in the Catalog!](https://play.date/games/playbook/)**

## How to Use

Welcome to PlayBook! This is an ebook reader specially designed for the Playdate, with some carefully thought out features to make reading on your Playdate a delight. This guide will walk you through how to use your new handheld library. Hope you enjoy!

### Adding Books

To get started, plug in your Playdate into your computer/phone and hold [D-Pad Left] + [Lock Button] + [Menu Button] at the same time for five seconds. This will restart the Playdate and put it into USB mode where the files will then be accessible from your device. From your computer/phone, open the "PLAYDATE" drive and go to "Data", then "com.idreesinc.playbook", then "books" which will be initially empty.

PlayBook doesn't support EPUB books directly because that's difficult for such a tiny device. ~~Instead, you'll need to take your EPUB file and use one of the many EPUB to TXT converters available online. I don't recommend using the TXT files directly from Project Gutenberg as they have too many line breaks, instead grab the EPUB files and convert them to TXT yourself.~~

* You can now use the bundled EPUB to PDB converter to convert your EPUB file and get chapters and hyphenation at the same time.

Take your TXT file and place it directly in the "books" folder. I'd recommend giving it a good name like "A Cool Book.txt" so it's more readable (spaces and capitals work just fine). And that's it! You can now eject the "PLAYDATE" drive and unplug your device. Your book will now be available in the PlayBook app.

### Using PlayBook

When you open PlayBook, you'll be greeted with a list of all the books you've added. You can use the crank or D-pad to scroll through your library and press [A] to open a book. Once you've opened a book, you can use the crank or D-pad to scroll through the book. You can also ~~press [B]~~ to go back to the book list.

* To get to the library, press the menu button and select Library from the pause menu.

On the right side of the screen, you'll see a candle animation. This is your progress bar. The candle will slowly burn down as you read through the book, flickering away as you turn the crank. You can disable the candle in the settings if you'd prefer.

* Technically the candle doesn't flicker unless you're turning the page the crank now, because animation stops when you stop touching the controls. I still think that's worth it for the battery saving.

To access the settings, ~~press [A] while reading a book~~. From here, you can change the color scheme, font, crank speed, and more.

* Settings are now in the pause menu, along with navigation.


That's all there is to it! I hope you enjoy using PlayBook and reading on your Playdate. If you have any questions or feedback, feel free to reach out to me at [idreesinc.com](idreesinc.com) which will have all of my contact information. Thanks for getting PlayBook and happy reading!
