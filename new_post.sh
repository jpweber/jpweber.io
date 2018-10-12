#!/bin/bash
# help script for writing new posts
/usr/local/bin/hugo new post/${1}.md
open -a Typora ./content/post/${1}.md