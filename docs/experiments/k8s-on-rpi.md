## Short version

[Gist from Alex Ellis](https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975)

## Long version

[Blog by Scott Hanselman](https://www.hanselman.com/blog/HowToBuildAKubernetesClusterWithARMRaspberryPiThenRunNETCoreOnOpenFaas.aspx)

If you set up one Raspberry Pi and clone the SD-card, make sure to edit /etc/machine-id to ensure its a unique id otherwise Kubernetes plugins like Weave-net will fail.

## Our customisations (in progress)
Stuff that we did to make the set-up ready for Kubernetes configuration.

We downloaded [Rasbian Stretch (with desktop)](https://www.raspberrypi.org/downloads/raspbian/)  and used [https://etcher.io/](etcher) to burn the image to a empty micro SD card. After booting up we made the following changes to the baseline installation:

  * Changed default password for user 'pi'
  * Changed hostname
  * Changes to boot-to-cli
  * Added locale for NO NB UTF-8, and selected proper keyboard
  * Selected proper time-zone
  * Enables SSH
  * Adapting Wifi-to connect to "Statoil-Approved" by adding the following to "/etc/wpa_supplicant/wpa_supplicant.conf" (replacing user id and password)
```
  country=NO
  ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
  update_config=1
  
  network={
    ssid="Statoil-Approved"
    priority=1
    proto=RSN
    key_mgmt=WPA-EAP
    pairwise=CCMP
    auth_alg=OPEN
    eap=PEAP
    identity="<userid>"
    password="<password>"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
  }
```

  * Doing a <code>sudo apt-get update & sudo apt-get upgrade & reboot</code>
  * Installed basic software and doing config following the Hanselman recipe
  * Docker
<code>curl -sSL get.docker.com | sh && \ sudo usermod pi -aG docker</code>
  * Disabling swap
<code>sudo dphys-swapfile swapoff && \ sudo dphys-swapfile uninstall && \ sudo update-rc.d dphys-swapfile remove</code>
  * Edit "/boot/cmdline" and add the following to statements at the end "cgroup_enable=cpuset cgroup_enable=memory". Make sure that the line does not have a CRLF.
  * Install Kubernetes
<code>curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \ echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \ sudo apt-get update -q && \ sudo apt-get install -qy kubeadm </code>
  * Adding network interface to the RJ45 (eth0) by editing "/etc/network/interfaces"

```
#Lan
auto eth0
iface eth0 inet static
	address 192.168.10.1
	netmask 255.255.255.0
	gateway 192.168.10.1
	dns-nameservers 143.97.38.116 143.97.38.117
	#post-up iptables-restore < /etc/iptables/rules.v4
```
* Added a hosts file to /etc/hosts to name master and nodes.

In our set-up the master node is connected to the outside world using wifi, while the node & master is connected together using cable. The nodes do not have direct access to the outside world.

When we had the baseline image ready we shutdown the pi and copied the image to a computer ready for duplication using etcher.

**Changes to the master node once it was up and running:**
  * Setting up IP forwarding from node -> master -> world (Wifi
```
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
```
  * Enabling IP forwarding by doing <code>echo "1"> /proc/sys/net/ipv4/ip_forward</code> as root
  * Loading IP Forwarding by putting code in script on load on post-up on wlan0
  * Announce "external" IP to Slack by adding a script with @reboot to crontab

**Changes that needed to be done one each individual node:**

  * Change hostname, static-ip, (and /etc/machine-id)
  * Disabled Wifi interface