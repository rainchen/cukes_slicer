CucumberSlicer
==============
Run all cucumber features in parallel(each feature using an independent db for testing).
[![Cucumber Slicer](http://farm5.static.flickr.com/4058/4226659487_c203f6eff1_o_d.png)](http://github.com/rainchen/cukes_slicer "Cucumber Slicer")  

== Steps
   1. Create tmp dir (TODO: use a memory dir)
   2. Prepare test.db (sqlite db with seed data)
   3. Copy test.db for each feature
   4. Run cucumber with it's db in parallel and log the out put.
   5. Collect all logs and analyze the logs
   6. Clear tmp dir

== Requirement
  cucumber --version >= 0.4.4

== Install
  script/plugin install git://github.com/rainchen/cukes_slicer.git

== Usage
  rake cucumber:slicer
  
== Help
  rake -T cucumber:slicer
  http://github.com/rainchen/cukes_slicer

Copyright (c) 2009 [RainChen], released under the MIT license
