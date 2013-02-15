# utubepub


Scripts to automate the creation and upload of music learning videos to YouTube.

#### Background

I was asked to investigate if it were possible to automate the creation and upload of music learning videos to [YouTube](youtube.com) for [stmaryssingers.com](stmaryssingers.com). The results are [here](http://www.youtube.com/user/StMSSyd).

While not completely automated, this repo contains a set of tools I developed to assist the process.

#### What these scripts do

* `makmov.pl`  
	Assuming I have used Sibelius 6 with plugins mentioned below to create:  
	`song_satb.aiff`,  
	`song_s.aiff`,  
	`song_a.aiff`,  
	`song_t.aiff`,  
	and `song_b.aiff`  
from `song.sib`, 
and Sibelius First to create `song.mov`,
`makmov.pl` will create a YouTube-compatible video for each part in addition to the
SATB video, then it will load each video up to YouTube together with a description
which contains links to the other parts. I put this file in `/usr/local/bin` but it can go anywhere in your PATH.
* `sibplugins/Playback/SetVoicePan.plg` creates the separate voice parts (i.e. Sop, Alto, Tenor and Bass) as `.aiff` files from the currently open Sibelius file. Builds a sound stage with the selected part in the centre and the other parts (including accompaniment) moved left and right of centre stage. Boosts the volume of centre part, reduces volume of other parts.
* `sibplugins/Playback/SetVoiceName.plg` changes part names to Sop1, Sop2 etc. so SetVoicePan can correctly identify the parts.
* `sibplugins/Playback/SetPiano.plg` changes all instruments to Piano. This is simply because Piano seems to give the most clarity of notes for learning.
* `sibplugins/Text/DeleteDynamics.plg` deletes all the `p`, `pp`, `ff` etc. dynamic marks from a Sibelius file. When one is note-bashing to learn a song, no-one needs soft and loud phrases.
* `makaud.pl` a cut-down version of `makmov.pl` which only converts the `.aiff` files produced by `SetVoicePan` into normalised `.mp3` files. Rarely used these days.
 
#### Pre-requisites
* Sibelius 6 or later, to run the Sibelius plugins.
* Sibelius 7 First, a low-cost version of Sib7 which exports scores as videos, suitable for uploading to YouTube.
* PhotoScore Ultimate or equivalent to convert PDFs of music scores into files suitable for importing into Sibelius. (PhotoScore can also scan a printed score if needed.)
* Perl 5.10 or later
* Some Perl CPAN modules
	* `WebService::GData::YouTube`
	* `WebService::GData::ClientLogin`
	* `Getopt::Long`
	* `autodie`
	* `Config::Tiny` to read your YouTube credentials file.
* `ffmpeg` 0.11.2+
* `sox` 14.4.0+
* `youtube-upload` from [here](http://code.google.com/p/youtube-upload)

#### Setting up the tools
You need to install the `*.plg` plugins in your Sibelius 6 Plugins directory. On my Mac it's at:
`~/Library/Application Support/Sibelius Software/Sibelius 6/Plugins`

Drop `sibplugins/Text/DeleteDynamics.plg` into the `Text` directory and `sibplugins/Playback/Set*.plg` files into the `Playback` directory.

You need to create a YouTube Developer Key (see [here](https://developers.google.com/youtube/2.0/developers_guide_protocol_uploading_videos))

Then create a credentials (text) file using your favorite editor. I created mine as `~/.youtube/cred.conf` with permissions set to 600 (i.e only I can read and write the file). The file reads like this:

	Email=myemail@gmail.com
	Password=mypassword
	Key=myreallylongyoutubedeveloperkey
	
#### The process flow
1. Download and/or open a .sib file in Sibelius 6. [CPDL](cpdl.org) is your friend for downloads. Use PhotoScore to convert a PDF to .sib if necessary.
2. Clean it up:
	* Use the Text/Delete Dynamics plugin to remove anything that changes the volume. This audio is for learning to sing the notes and it helps to be able to hear them.
	* Clean up the lyric lines.
	* Open the Score Info window (File/Score Info) and set the composition name and the composer. YouTube requires these fields.
	* Set the audio mix to all parts in centre stage.
	* Show the staff rulers (View-&gt;Rulers-&gt;Staff Rulers) and adjust the inter-staff spacing:
		* 29 from the top,
		* 12 between each singing part,
		* 14 between Piano staves.
	* Export Audio and save it as song_satb.aiff.
	* Save the .sib file so you can exit after running `SetVoicePan` without having to reset the Mixer controls.
	* Run the Playback/SetPiano plugin to set all voices to Piano. Makes it easier to distinguish notes when learning.
	* Run the Playback/SetVoicePan to export an AIFF file for each vocal part in the score.
	* Use Finder or rename to adjust the names of the AIFF files so there is no digit in the filename if there is only one part in that voice e.g. song_a1.aiff should be song_a.aiff if there is only one alto part. But no need to change names if there is an alto1 and alto2 part.
	* Exit Sibelius 6 but don't re-save the file.
3. Open the .sib file in Sibelius 7 First and export it as a video:
	* Click 'File'
	* Click 'Export'
	* Click 'Video'
	* Deselect 'Use score paper texture'
	* Select Resolution as 'HD (720p)'
	* Edit the filename (default should be song.mov).
	* Click 'Export'
4. Run `makmov.pl --file songfilename --title 'Song Title' --parts 's a t b' -o 33 -i 132`  
adjusting parameters as appropriate (see comments in `makmov.pl`). `makmov.pl` will pause after creating a single-frame PNG from the movie and the overlay PNGs (called `gradient_*.png`).
	* Use `Preview` app to line up the single frame and the gradients. Stop the script (^C) and restart with different '-o' and '-i' values if they don't line up.
	* When all is OK, press 'Return' after the pause and process will create all the individual videos, upload them to YouTube and rewrite their description text with links to the other parts in the song.

#### A warning about YouTube copyright trolls
No matter how old the music you upload is, no matter how many centuries it's been out of copyright you will almost certainly get a copyright infringment notice (they are trying to get their ads on your site so they can get Google click thrus). Harry Fox Agency is the worst but the others aren't far behind. If you are using public domain scores (e.g from [CPDL](cpdl.org)) and you are using the scripts in this repo to create the videos, none of their claims are valid. It's your version of a public domain work. YouTube can guide you through the procedures to dispute the claims (Google for some of the necessary wording). HFA might refuse your first dispute but when you proceed to stage 2 they back off. Some of the trolls have an automatic script which relinquishes any claim which is challenged (Google is paying for all this of course). But make sure your music is truly public domain or you own the copyright.





