#!/usr/bin/env bash

### PURPOSE
#
# Demonstrate how to break out of subshells without exiting the main/parent script.
# In other words, how to "skip" never ending loops and continue with the next step in the main script.

### USAGE
#
# Call this script, then use ctrl+c to break out of the loops and see that the main script continues to the next step after the loop

### THE TRICK: use trap
#
# Trap ctrl+c and call a function that ask the user to continue or exit script.
trap user_skip_subshell SIGINT

### SOME DEMO FUNCS

function user_skip_subshell() {
   echo -e "\n-------------------"
   echo -e "User told me to skip this step..."
   while true; do
      read -r -p "Do you want to continue with the next steps? (Y/n) " yn
      case $yn in
      # "exit" will break out of the subshell
      # If you want to break out of a while loop in main/parent script then you would use "break"
      [Yy]*)
         echo ""
         echo "Continuing with next steps..."
         break
         ;;
      [Nn]*)
         echo ""
         echo "Quitting script."
         echo "-------------------" exit 0
         ;;
      *) echo "Please answer yes or no." ;;
      esac
   done
}

function everloop() {
   local text="$1"
   local iterator=0
   while [ "$iterator" -eq 0 ]; do
      echo "$text"
      sleep 1
   done
}

function do_step_2() {
   echo "Step 2: Doing something else...Done"
}

## MAIN

# Call loop function in subshell
(everloop "Step 1: Never ending story")
# Do some more work after subshell
do_step_2
# Call yet another loop function in a subshell
(everloop "Step 3: More loops4tehwin, weeeeeeeeee")

## END
echo "Script done - THE END."
