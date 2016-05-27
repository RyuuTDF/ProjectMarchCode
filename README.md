# ProjectMarchCode
Code for the monitoring system

How to use
==============

Setup Local
--------------
- execute StressTest.slx
- in SimpleGui.mat, execute SimpleGui.testStream
- if this doesn't work, make sure the IP-adresses in NetworkEnv.mat are configured correctly

GUI
--------------

- in order to change certain parameters like the size or update rate, load 'GuiConfig.mat', change the parameter in the config struct and save the changed config to 'GuiConfig.mat'
- in order to toggle updates, select the checkbox in the upper left
- in order to view all sensors, select the checkbox in the upper right
