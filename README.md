# Raspberry Pi Setup

### Serial GPIO

#### Swapping ports used by GPIO and Bluetooth
The first thing to enable serial connection is to swap ports used by the GPIO (soldered pins) and the internal Bluetooth chip. We need to add a line in the config file on the boot partition.

```shell script
sudo nano /boot/config.txt
```
Move the cursor to the very end and add:
`dtoverlay=pi3-miniuart-bt`

#### Disabling the serial console
Moving to another config file, where part of the code must be deleted to disable the serial console.

```shell script
sudo nano /boot/cmdline.txt
```
Look for following string (text) and delete it
`console=serial0,115200`

## Ser2net

Install ser2net
```shell script
sudo apt install ser2net
```

```shell script
sudo nano /etc/ser2net.conf
```
Scroll to the bottom of the file and replace 
```
2000:telnet:600:/dev/ttyS0:9600 8DATABITS NONE 1STOPBIT banner
2001:telnet:600:/dev/ttyS1:9600 8DATABITS NONE 1STOPBIT banner
3000:telnet:600:/dev/ttyS0:19200 8DATABITS NONE 1STOPBIT banner
3001:telnet:600:/dev/ttyS1:19200 8DATABITS NONE 1STOPBIT banner
```
with, replacing `/dev/ttyAMA0` with the tty device for your printer
```
2000:telnet:600:/dev/ttyAMA0:115200 8DATABITS NONE 1STOPBIT banner
```
Restart ser2net
```shell script
sudo systemctl enable ser2net
sudo systemctl restart ser2net
```
Verify connectivity by running the following
```shell script
telnet localhost 2000
```
type `M105` into the console, hit return, you should get temperature report back
```
ok T:215.1 /215.0 B:60.4 /60.0 T0:215.1 /215.0 @:108 B@:4 P:30.9 A:49.3
```

## mjpeg-streamer
Clone / Compile mjpeg streamer
```shell script
sudo apt install git subversion libjpeg62-turbo-dev imagemagick ffmpeg libv4l-dev cmake
git clone https://github.com/jacksonliam/mjpg-streamer.git
cd mjpg-streamer/mjpg-streamer-experimental
export LD_LIBRARY_PATH=.
make
```
This should hopefully run through without any compilation errors. You should then be able to start the webcam server using
```shell script
./mjpg_streamer -i "./input_uvc.so" -o "./output_http.so"
```
This should give the following output:
```
MJPG Streamer Version: svn rev:
 i: Using V4L2 device.: /dev/video0
 i: Desired Resolution: 640 x 480
 i: Frames Per Second.: 5
 i: Format............: MJPEG
[...]
 o: www-folder-path...: disabled
 o: HTTP TCP port.....: 8080
 o: username:password.: disabled
 o: commands..........: enabled
```
If you now point your browser to `http://<your Raspi's IP>:8080/?action=stream`, you should see a moving picture at 5fps

Create a start script for mjpeg streamer
```shell script
sudo nano /usr/local/bin/webcamDaemon
```
```shell script
#!/bin/bash

MJPGSTREAMER_HOME=/home/pi/mjpg-streamer/mjpg-streamer-experimental
MJPGSTREAMER_INPUT_USB="input_uvc.so"
MJPGSTREAMER_INPUT_RASPICAM="input_raspicam.so"

# init configuration
camera="auto"
camera_usb_options="-r 1640x1232 -f 15"
camera_raspi_options="-fps 15"

if [ -e "/boot/octopi.txt" ]; then
    source "/boot/octopi.txt"
fi

# runs MJPG Streamer, using the provided input plugin + configuration
function runMjpgStreamer {
    input=$1
    pushd $MJPGSTREAMER_HOME
    echo Running ./mjpg_streamer -o "output_http.so -w ./www" -i "$input"
    LD_LIBRARY_PATH=. ./mjpg_streamer -o "output_http.so -w ./www" -i "$input"
    popd
}

# starts up the RasPiCam
function startRaspi {
    logger "Starting Raspberry Pi camera"
    runMjpgStreamer "$MJPGSTREAMER_INPUT_RASPICAM $camera_raspi_options"
}

# starts up the USB webcam
function startUsb {
    logger "Starting USB webcam"
    runMjpgStreamer "$MJPGSTREAMER_INPUT_USB $camera_usb_options"
}

# we need this to prevent the later calls to vcgencmd from blocking
# I have no idea why, but that's how it is...
vcgencmd version

# echo configuration
echo camera: $camera
echo usb options: $camera_usb_options
echo raspi options: $camera_raspi_options

# keep mjpg streamer running if some camera is attached
while true; do
    if [ -e "/dev/video0" ] && { [ "$camera" = "auto" ] || [ "$camera" = "usb" ] ; }; then
        startUsb
    elif [ "`vcgencmd get_camera`" = "supported=1 detected=1" ] && { [ "$camera" = "auto" ] || [ "$camera" = "raspi" ] ; }; then
        startRaspi
    fi

    sleep 120
done
```
and make it executable
```shell script
sudo chmod +x /usr/local/bin/webcamDaemon
```
Create a unit for mjpeg streamer
```shell script
sudo nano /etc/systemd/system/webcamdaemon.service
```
```shell script
[Unit]
Description=WebcamDaemon

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/webcamDaemon

[Install]
WantedBy=multi-user.target
```
and start the service
```shell script
sudo systemctl daemon-reload
sudo systemctl enable webcamdaemon.service
sudo systemctl start webcamdaemon.service
```

## prometheus exporter
Install the binary
```shell script
wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-armv6.tar.gz
tar -xvzf node_exporter-0.18.1.linux-armv6.tar.gz
chmod +x node_exporter-0.18.1.linux-armv6/node_exporter
sudo cp node_exporter-0.18.1.linux-armv6/node_exporter /usr/local/bin
```
Create a unit for node exporter
```shell script
sudo nano /etc/systemd/system/node_exporter.service
```
```shell script
[Unit]
Description=Node Exporter

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```
And start the service
```shell script
sudo systemctl daemon-reload
sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service
```

# Octoprint Deployment
```yaml
apiVersion: v1
kind: Service
metadata:
  name: octoprint
  namespace: yonsea
spec:
  ports:
    - port: 80
      targetPort: 5000
  selector:
    app: octoprint
  clusterIP: None
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    service: octoprint
  name: octoprint
  namespace: yonsea
spec:
  strategy:
    type: Recreate
  replicas: 1
  selector:
    matchLabels:
      app: octoprint
  template:
    metadata:
      labels:
        app: octoprint
    spec:
      containers:
      - image: quay.io/jakekeeys/octoprint-socat
        imagePullPolicy: Always
        name: octoprint
        env:
          - name: SOCAT_TARGET
            value: "<raspberry-pi-host>:2000"
        ports:
        - containerPort: 5000
          protocol: TCP
        resources:
          requests:
            memory: 1000Mi
          limits:
            memory: 2000Mi
        volumeMounts:
          - mountPath: /data
            name: octoprint
      volumes:
        - name: octoprint
          persistentVolumeClaim:
            claimName: octoprint
```
