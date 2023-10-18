/*
// **************************************************************
GAIT APP DESIGN - ESTY

 Outline of Code for feedback from an IMU.
 
 *) Goal is to calculate the mean amplitude of all frequencies of a sample of the summed X, Y and Z vectors. This requires calculating the amplitude of all frequencies within the samples(using a FFT), taking the mean and summing the three values.The variables used to access the data are AccX, AccY and AccZ. This links to a description:
 https://www.brianesty.com/bodywork/2023/10/evaluating-how-we-interact-with-gravity/
 *) This calculated value describes the relative total energy used within a movement. From testing it is observed that energy can be "spilled" in all three vectors. I am reaching for a metric for efficiency or optimization in movement.
 *) If this value is displayed on a watch, and/or with haptic/audio feedback when a threshold is crossed, it provides dynamic feedback for the optimization or efficiency of movement, training both meurology and physiology. The relevance of this information has a very short lifespan, in the range of 1-2 seconds, requiring a quick feedback loop.
 *) NB: Intitial studies have benn done using a discrete IMU on the midline. However, once this is built, a version using the embedded IMU within the phone should be studied as initial results suggest that efficiency in all three vectors tightly correlates and that the position of the IMU on the body may be less critical than assumed.

 *******************************
 Questions:
 *) figure out the function of the 03 register (this is a button on the UI). No documentation found and the button does not seem to do anything.

 Notes:
 *) Default sample rate is 20 msec which seems about right.
 *) The raw accel data is souced from BWT901BLE5_0DataProcessor as regAx etc. It is converted into gravitational units before output to the UI as AccX etc.
***************************************************************
*/# WitmotionManubrium
