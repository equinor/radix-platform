#!/bin/bash

### PURPOSE
#
# Demonstrate how to break out of subshells without exiting the main/parent script.
# In other words, how to "skip" never ending loops and continue with the next step in the main script.

### USAGE
#
# Call this script, then use ctrl+c to break out of the loops and see that the main script continues to the next step after the loop


### THE TRICK: use trap
#
# Trap ctrl+c and call a function that said the user did so
# This behaves nicely if the code you want to skip is run in a subshell
trap user_skip SIGINT


### SOME DEMO FUNCS

function user_skip() {
   echo -e "\nUser told me to skip this..."
} 

function everloop() {
   local text="$1"
   local iterator=0   
   while [ "$iterator" -eq 0 ]; do
      echo "$text"
      sleep 1s
   done
}

function do_something_else() {
   echo "Doing something else...Done"
}


## MAIN

# Call loop function in subshell
(everloop "Never ending story")
# Do some more work after subshell
do_something_else
# Call yet another loop function in a subshell
(everloop "More loops4tehwin, weeeeeeeeee")


## END
echo "Script done - THE END."