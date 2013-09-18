#!/bin/bash -e

if [ -z "$PAM_USERNAME" ] || [ -z "$PRIVATE_SSH_KEY" ] || [ -z "$PUBLIC_SSH_KEY" ]; then
  echo you MUST set PAM_USERNAME and PRIVATE_SSH_KEY and PUBLIC_SSH_KEY to run this.
  exit 1
fi

useradd -m -d /home/${PAM_USERNAME} ${PAM_USERNAME}
sshdir=/home/${PAM_USERNAME}/.ssh
mkdir -p $sshdir

echo -e "$PRIVATE_SSH_KEY" > $sshdir/id_rsa 
chmod 600 $sshdir/id_rsa

echo -e "$PUBLIC_SSH_KEY" > $sshdir/authorized_keys

echo <<EOS> $sshdir/config
Host *
  StrictHostKeyChecking no
EOS

echo "SUCCESS! Created user ${PAM_USERNAME}"
