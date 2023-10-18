 # Outline of Code for Feedback from an IMU.
 
 * The goal is to calculate the mean amplitude of all frequencies of a sample of the summed X, Y, and Z vectors. This requires calculating the amplitude of all frequencies within the samples(using an FFT), taking the mean, and summing the three values. The variables used to access the data are AccX, AccY, and AccZ. This links to a description of the study:
 https://www.brianesty.com/bodywork/2023/10/evaluating-how-we-interact-with-gravity/
 
 * This calculated value describes the relative total energy used within a movement. From testing, it is observed that energy can be "spilled" in all three vectors. I am reaching for a metric for efficiency or optimization in movement.
 
 * If this value is displayed on a watch, and/or with haptic/audio feedback when a threshold is crossed, it provides dynamic feedback for the optimization or efficiency of movement, training both neurology and physiology. The relevance of this information has a very short lifespan, in the range of 1-2 seconds, requiring a quick feedback loop.
 
* An example of the application is to continually sample the three IMU acceleration readings. Every second the three arrays are processed (FFT, then Mean, then summed. 1 sec = 50 readings). The value can then be compared to a threshold value set in the UI. If true, then a haptic/audio alert is triggered. This facilitates training on routine/repetitive actions. More advanced options could use stored values and even reference changes in location using GPS.
