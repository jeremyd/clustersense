#!/bin/bash -ex

if [ -z "$PAM_USERNAME" ]; then
  echo you MUST set PAM_USERNAME.
  exit 1
fi

userdel -r $PAM_USERNAME
