sudo dpkg --configure -a
sudo apt-get install --reinstall -y python3-requests || true
sudo apt-get install -f -y || true
sudo apt update
sudo apt install -f -y /tmp/kamiwaza_0.4.1-rc1_noble_amd64_build2.deb
sudo dpkg --configure -a
sudo apt-get install -f -y || true
rm /tmp/kamiwaza_0.4.1-rc1_noble_amd64_build2.deb