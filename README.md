# iMan 0.4

Copyright (c) 2004-2011 by David Reed. This application and its source code are distributed under the terms of the BSD License, which should be included in this distribution.

**iMan is not currently maintained. This repository contains the version of iMan that was current as of 2012.**

iMan is a graphical viewing application for UNIX man pages (textual documentation files). iMan provides a Mac OS X native Aqua interface as an alternative to use of the man program via the Terminal. This directory contains almost everything you'll need to build or make changes to iMan: source code, resources, and and links to the third-party frameworks needed (see below). 

iMan is divided into two main parts, an application and an engine framework. The application, mostly controller layer, manages iMan's UI and interacts with the model layer, `iManEngine.framework`. The engine framework handles the low-level duties of asynchronously interfacing with the command line tools (man, groff, and makewhatis), parsing output, and sending that output in displayable form back to the UI. The engine could fairly easily be embedded in other applications that need this functionality.

Currently, iMan consists of the following major controller classes:

* `iMan`

   The delegate of `NSApplication`, handles various minor tasks and service invocations, including dispatching requests to load `man:` URLs. Also responsible for re-indexing, update checking, and maintaining the page database.

* `iManDocument`

   The "viewing window" class, `iManDocument` handles loading and display of man pages, as well as `apropos`/`whatis` searching.

* `iManPreferencesController`

  A fairly straightforward preference window controller. It will trigger re-scans of the page database when manpaths are edited.

* `iManIndexingWindowController`
  Handles updating the indexes and displaying progress.
	
* `iManURLHandler`
	This class is invoked to handle clicks on URLs of scheme "man:" and "x-man-page:" (see iMan.scriptTerminology). It calls through to `-[iMan loadExternalURL:]`.
	
A variety of small support classes and categories are, hopefully, more or less self-explanatory.
		
`iManEngine.framework` holds (among others) the following classes:

* `iManPage`
  This class represents a single page. It abstracts away all the work of rendering pages, which is done asynchronously via `iManRenderOperation`.
  
* `iManSection`

  This class represents a section (e.g., "1", "3ssl"). It maintains references to subsections (section 3 has 3pm and 3ssl) and to pages under that section. Note that pages are stored as paths, *not* as `iManPage` objects.
	
* iManSearch
  As `iManPage` is to rendering manpages, `iManSearch` is to searching them. It provides an API that supports future expansion (like SearchKit indexing/searching), though currently it provides only `apropos`/`whatis` searches. Its work is also done asynchronously via `iManSearchOperation`.
  
* `iManIndex`

  `iManIndex` represents one of the theoretically more than one indexes used by `iManSearch` (right now, there is only the singleton `iManAproposIndex`). It also handles the low-level business of updating indices via `iManMakewhatisOperation`. The index is stored in a file in our Application Support directory.
	
* `iManPageDatabase`

  `iManPageDatabase` maintains an index of all of the manpages found in the currently configured manpaths so that they may be looked up quickly by name and section. This class is thread safe.
	
* `iManPageCache`
  This singleton class manages the cache of `iManPage` instances. It watches for pages to finish rendering and saves the cached version to disk in a background thread.
  
* `iManEnginePreferences`
  This class manages manpaths and tool paths. Called by both UI and engine. This class is thread safe.

iMan also requires three external libraries:

* [RegexKitLite](http://regexkit.sourceforge.net/), by John Englehart. A modified version of Mr. Englehart's supplied example `RKLMatchEnumerator.m` is included with iMan.
* [Sparkle](http://sparkle.andymatuschak.org/), by Andy Matusczak. 
* [RBSplitView](http://brockerhoff.net/src/rbs.html), by Rainier Brockerhoff

Place Sparkle.framework, the RegexKitLite folder, and the RBSplitView folder in the base iMan directory of the source checkout and the project will find them (if versions or directory names have changed, you may need to adjust references within the project file).

The source code is fairly lightly commented. (Better documentation is on the to-do list). Documentation for iManEngine is included in HeaderDoc comments. If you have questions (or patches, or bugs, or improvements, or...), please send me an email.

-- [David Reed](mailto:david@ktema.org)
