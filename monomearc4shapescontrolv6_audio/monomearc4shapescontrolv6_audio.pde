import org.monome.Monome;
import oscP5.*;
import ddf.minim.*;  // Import the Minim library for audio playback


Monome m;
Minim minim;
AudioPlayer player;  // To handle the audio playback
int[] positions;  // Track each encoder's position (0 to 64)
int numLeds = 64;  // Number of LEDs in each encoder ring
float[] rotationSpeeds;  // Track rotation speeds for each encoder's object
float[] angles;  // Track the rotation angle for each encoder's object
int[] objectTypes;  // Store the type of object for each encoder
color[] objectColors;  // Store object colors for each object
PVector[] objectSizes;  // Store object sizes for each encoder
float[] playheadPositions;  // Track playhead positions for visual looping
float[] playheadSpeeds;  // Playhead speed for each encoder
color bgColor;  // Background color

public void setup() {
  size(2560, 1400, P3D);  // Set up 3D canvas
  
  // Initialize Monome with correct serial number
  println("Initializing Monome with serial number: m0000007");
  m = new Monome(this, "m0000007");
  
  if (m == null) {
    println("Monome object failed to initialize");
  } else {
    println("Monome object initialized successfully");
  }
  
  // Initialize Minim and load the audio file
  minim = new Minim(this);
  player = minim.loadFile("Super_Colitis_new.mp3");  // audio file
  player.loop();  // Set the audio file to loop
  
  positions = new int[4];  // Track positions for 4 encoders
  playheadPositions = new float[4];  // Playhead positions for visual loops
  rotationSpeeds = new float[4];  // Store rotation speed for each object
  angles = new float[4];  // Rotation angles for each object
  objectTypes = new int[4];  // Type of object for each encoder
  objectColors = new color[4];  // Object colors
  objectSizes = new PVector[4];  // Store the object size for each encoder
  
  // Set playhead speeds to the new values
  playheadSpeeds = new float[]{1.0, 0.8, 0.5, 0.2};  // Faster playhead speeds

  // Initialize default values
  for (int i = 0; i < 4; i++) {
    rotationSpeeds[i] = random(0.01, 0.05);  // Random initial speed
    angles[i] = 0;
    objectTypes[i] = int(random(3));  // Random object type (0 to 2)
    objectColors[i] = color(random(255), random(255), random(255));  // Random color
    objectSizes[i] = new PVector(100 + random(50), 50 + random(50), 50 + random(50));  // Random size
    playheadPositions[i] = 0;  // Initialize playhead at position 0
    println("Initialized encoder " + i);
  }
  
  // Set initial background color
  bgColor = color(0);
}

public void draw() {
  background(bgColor);  // Dynamic background color
  lights();  // Enable lighting

  // Loop through all four encoders
  for (int i = 0; i < 4; i++) {
    // Update rotation angle based on each encoder's rotation speed
    angles[i] += rotationSpeeds[i] * playheadSpeeds[i];  // Object movement relative to playhead speed

    // Draw objects freely in the canvas
    pushMatrix();
    translate(random(width), random(height), random(-200, 200));  // Random position within canvas
    
    // Set transparency and wireframe style
    stroke(objectColors[i], 120);  // Semi-transparent colored lines
    noFill();  // Do not fill the shapes
    
    // Rotate the object
    rotateY(angles[i]);
    rotateX(angles[i] * 0.5);
    
    // Draw the object based on its type
    drawObject(i);
    
    popMatrix();
    
    // Update the LEDs to reflect the encoder's playhead
    updateLEDs(i);
    
    // Update the playhead for each encoder to simulate looping
    playheadPositions[i] = (playheadPositions[i] + playheadSpeeds[i]);
    if (playheadPositions[i] >= numLeds) {
      playheadPositions[i] -= numLeds;
    }
    
    // Every 1/4 of the playhead cycle, change the rotational speed
    if (int(playheadPositions[i]) % (numLeds / 4) == 0) {
      rotationSpeeds[i] = random(0.01, 0.05);  // Change rotation speed randomly
    }
  }
}

// Add stop() to stop the audio when the sketch is closed
public void stop() {
  player.close();
  minim.stop();
  super.stop();
}

// Draw the current object for each encoder
public void drawObject(int encoderIndex) {
  switch (objectTypes[encoderIndex]) {
    case 0:
      drawComplexTorus(objectSizes[encoderIndex].x, objectSizes[encoderIndex].y);
      break;
    case 1:
      drawWavyTorus(objectSizes[encoderIndex].x, objectSizes[encoderIndex].y);
      break;
    case 2:
      drawOscillatingSphere(objectSizes[encoderIndex].x);
      break;
  }
}

// Custom function to draw a complex torus
public void drawComplexTorus(float r1, float r2) {
  int sides = 48;  // More sides for higher fidelity
  int rings = 48;  // More rings for higher complexity
  for (int i = 0; i < sides; i++) {
    float theta1 = TWO_PI * i / sides;
    float theta2 = TWO_PI * (i + 1) / sides;
    beginShape(LINES);  // Draw wireframe
    for (int j = 0; j <= rings; j++) {
      float phi = TWO_PI * j / rings;
      float x1 = (r1 + r2 * cos(phi)) * cos(theta1);
      float y1 = (r1 + r2 * cos(phi)) * sin(theta1);
      float z1 = r2 * sin(phi);
      float x2 = (r1 + r2 * cos(phi)) * cos(theta2);
      float y2 = (r1 + r2 * cos(phi)) * sin(theta2);
      float z2 = r2 * sin(phi);
      vertex(x1, y1, z1);
      vertex(x2, y2, z2);
    }
    endShape();
  }
}

// Custom function to draw a wavy torus
public void drawWavyTorus(float r1, float r2) {
  int sides = 32;
  int rings = 32;
  for (int i = 0; i < sides; i++) {
    float theta1 = TWO_PI * i / sides;
    float theta2 = TWO_PI * (i + 1) / sides;
    beginShape(LINES);  // Draw wireframe
    for (int j = 0; j <= rings; j++) {
      float phi = TWO_PI * j / rings;
      float x1 = (r1 + r2 * cos(phi) + sin(theta1 * 5) * 20) * cos(theta1);
      float y1 = (r1 + r2 * cos(phi) + sin(theta1 * 5) * 20) * sin(theta1);
      float z1 = r2 * sin(phi);
      float x2 = (r1 + r2 * cos(phi) + sin(theta2 * 5) * 20) * cos(theta2);
      float y2 = (r1 + r2 * cos(phi) + sin(theta2 * 5) * 20) * sin(theta2);
      float z2 = r2 * sin(phi);
      vertex(x1, y1, z1);
      vertex(x2, y2, z2);
    }
    endShape();
  }
}

// Custom function to draw an oscillating sphere
public void drawOscillatingSphere(float size) {
  int detail = 32;  // Higher detail for the sphere
  for (int i = 0; i < detail; i++) {
    float theta = TWO_PI * i / detail;
    for (int j = 0; j < detail; j++) {
      float phi = PI * j / detail;
      float x = size * sin(phi) * cos(theta);
      float y = size * sin(phi) * sin(theta);
      float z = size * cos(phi);
      point(x, y, z);  // Use points to create a particle-like effect
    }
  }
}

// Update the LEDs for each encoder based on the position and playhead
public void updateLEDs(int encoderIndex) {
  int[] led = new int[numLeds];  // Create LED array for the encoder
  
  // Set all LEDs to low brightness
  for (int i = 0; i < numLeds; i++) {
    led[i] = 2;  // Low brightness
  }
  
  // Set markers at each 1/4 point of the cycle
  for (int i = 0; i < 4; i++) {
    int markerPos = (i * numLeds) / 4;
    led[markerPos] = 8;  // Medium brightness for markers
  }
  
  // Set the playhead LED to full brightness
  led[(int)playheadPositions[encoderIndex]] = 15;  // Full brightness for playhead
  
  // Refresh the LEDs for the encoder
  m.refresh(encoderIndex, led);
  println("Refreshing LEDs for encoder " + encoderIndex + " with playhead at " + (int)playheadPositions[encoderIndex]);
}

// Handle encoder rotation (delta)
public void delta(int n, int d) {
  // n = encoder index, d = delta (change in rotation)
  println("Encoder " + n + " rotated by " + d);  // Log encoder activity
  
  // Update position
  positions[n] += d;
  positions[n] = constrain(positions[n], 0, numLeds);  // Constrain between 0 and 64
  
  // Update the size of the object based on the encoder's position
  objectSizes[n].x = positions[n] * 2;  // Scale based on position
  
  // Update rotation direction based on encoder movement
  rotationSpeeds[n] = d > 0 ? random(0.02, 0.06) : random(-0.02, -0.06);
  
  // Print the encoder position to the console
  println("Encoder " + n + " moved. New position: " + positions[n]);
}

// Handle encoder button presses
public void key(int n, int s) {
  // If button is pressed (s = 1), generate a new object for this encoder
  if (s == 1) {
    println("Encoder " + n + " pressed. Generating new object.");
    objectTypes[n] = int(random(3));  // Random object type
    objectColors[n] = color(random(255), random(255), random(255));  // Random object color
    bgColor = color(random(255), random(255), random(255));  // Change background color
    rotationSpeeds[n] = random(0.01, 0.05);  // Random initial rotation speed
    angles[n] = 0;  // Reset rotation angle
  }
}
