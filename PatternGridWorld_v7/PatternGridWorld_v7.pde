import org.monome.Monome;
import oscP5.*;
import netP5.*;
import java.util.ArrayList;

Monome g;
int[][] grid_led = new int[8][16];  // 8 rows x 16 columns for the monome grid
boolean grid_dirty = true;

// ARC and object-related code (kept for OSC/netP5 handling)
Monome a;
int arc_numLeds = 64;
int[] arc_led = new int[arc_numLeds];
int[] arc_positions = new int[4];
boolean arc_dirty = true;

PVector[] objectPositions = new PVector[4];
int[] objectTypes = new int[4];
color[] objectColors = new color[4];
float maxObjectSize = 750;
color bgColor = color(0, 0, 0, 255);  // initial background color

float[] freqX = new float[4];
float[] freqY = new float[4];
float[] freqZ = new float[4];
int[][] faderPositions = new int[4][3];
float maxFreq = 0.007;
float minFreq = 0.00005;

int[] oscillationFaderPositions = new int[4];
float[] oscillationAmplitudes = new float[4];
float minOscillationAmplitude = 0;
float maxOscillationAmplitude = 200;
float oscillationSpeed = 0.10;

OscP5 oscP5;

// ---------------- Global variables for the grid visualization ----------------
// Cube size is set to 40.
float cubeSize = 40;
float spacingXY = 10;
float spacingZ = 10;
float gridWidth = 16 * (cubeSize + spacingXY) - spacingXY;
float gridHeight = 8 * (cubeSize + spacingXY) - spacingXY;
float gridDepth = 16 * (cubeSize + spacingZ) - spacingZ;  // 16 states deep

// For random LED state updating (every 25ms)
int lastRandomUpdate = 0;
boolean[][] isRandom = new boolean[8][16];

// Global colors for neurons:
// Resting neurons start with a softer blue (RGB 100,150,255) with an initial alpha of 20.
color restingColor = color(100, 150, 255, 20);
// Active neurons start as yellow with an alpha of 200.
color activeColor = color(255, 255, 0, 200);

// Global connection opacity (controlled by encoder 3)
float connectionOpacity = 200;

// Global list of connection objects.
ArrayList<Connection> connections = new ArrayList<Connection>();

// ---------------- Precomputed positions for all 2048 neurons ----------------
PVector[] allNeuronPositions; // will have 8 * 16 * 16 elements

// ---------------- Connection class ----------------
// Each connection stores the 3D positions of its endpoints (as determined when created),
// the stroke color (taken from activeColor at creation), and the creation time so it can be removed after 5 seconds.
class Connection {
  PVector start;
  PVector end;
  int col;
  float createdTime;
  
  Connection(PVector start, PVector end, int col) {
    this.start = start;
    this.end = end;
    this.col = col;
    this.createdTime = millis();
  }
}

public void setup() {
  size(1560, 1400, P3D);
  // Initialize monome devices – retained for OSC/netP5 handling
  g = new Monome(this, "m29496721");
  a = new Monome(this, "m0000007");
  
  // Initialize OSC listening on port 3333
  oscP5 = new OscP5(this, 3333);
  
  // Initialize the 4 topographic shapes (retained code)
  for (int i = 0; i < 4; i++) {
    objectPositions[i] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
    objectTypes[i] = int(random(4));
    objectColors[i] = color(random(255), random(255), random(255));
    for (int j = 0; j < 3; j++) {
      faderPositions[i][j] = 4;
      updateFrequency(i, j);
    }
    oscillationFaderPositions[i] = 4;
    updateOscillation(i);
  }
  
  // Initialize all grid buttons: brightness starts at 0 and randomization is active.
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 16; c++) {
      grid_led[r][c] = 0;
      isRandom[r][c] = true;
    }
  }
  
  // Precompute the positions for all 2048 neurons.
  int totalNeurons = 8 * 16 * 16;
  allNeuronPositions = new PVector[totalNeurons];
  int idx = 0;
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 16; c++) {
      for (int l = 0; l < 16; l++) {
        float x = c * (cubeSize + spacingXY) + cubeSize/2;
        float y = r * (cubeSize + spacingXY) + cubeSize/2;
        float z = l * (cubeSize + spacingZ) + cubeSize/2;
        allNeuronPositions[idx++] = new PVector(x, y, z);
      }
    }
  }
}

public void draw() {
  background(bgColor);
  
  // Update random LED states every 25ms (if randomization is active)
  if (millis() - lastRandomUpdate > 25) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 16; c++) {
        if (isRandom[r][c]) {
          grid_led[r][c] = int(random(16)); // random brightness 0-15
          grid_dirty = true;
        }
      }
    }
    lastRandomUpdate = millis();
  }
  
  // Draw the 3D grid and neuron connections within the same coordinate space.
  pushMatrix();
    // Center the grid and apply rotation for 3D perspective.
    translate(width/2, height/2, 0);
    rotateX(PI/6);
    rotateY(PI/4);
    translate(-gridWidth/2, -gridHeight/2, -gridDepth/2);
    
    // Draw the grid cubes.
    drawMonomeGrid3D();
    
    // Sample random pairs from all 2048 neurons and potentially add connections.
    checkAndAddConnections();
    
    // Draw existing connections (removing any older than 5 seconds).
    drawConnections();
  popMatrix();
  
  // Refresh monome grid if updated.
  if (grid_dirty) {
    g.refresh(grid_led);
    grid_dirty = false;
  }
  if (arc_dirty) {
    for (int i = 0; i < 4; i++) {
      update_arc_leds(i);
    }
    arc_dirty = false;
  }
}

// ---------------- Draw the 3D grid ----------------
// For each button (row, col), draw a vertical stack of 16 cubes.
// The cube at the active state (level == grid_led[r][c]) uses activeColor; all others use restingColor.
void drawMonomeGrid3D() {
  for (int row = 0; row < 8; row++) {
    for (int col = 0; col < 16; col++) {
      int brightness = grid_led[row][col];  // active level (0-15)
      for (int level = 0; level < 16; level++) {
        pushMatrix();
          float xPos = col * (cubeSize + spacingXY);
          float yPos = row * (cubeSize + spacingXY);
          float zPos = level * (cubeSize + spacingZ);
          translate(xPos, yPos, zPos);
          if (level == brightness) {
            fill(activeColor);
          } else {
            fill(restingColor);
          }
          stroke(0, 50);
          box(cubeSize);
        popMatrix();
      }
    }
  }
}

// ---------------- Helper: Get the center of a specific cube in the grid ----------------
PVector getCubeCenter(int r, int c, int level) {
  float x = c * (cubeSize + spacingXY) + cubeSize/2;
  float y = r * (cubeSize + spacingXY) + cubeSize/2;
  float z = level * (cubeSize + spacingZ) + cubeSize/2;
  return new PVector(x, y, z);
}

// ---------------- Check and add connections between neurons ----------------
// Instead of iterating over every pair (which would be computationally heavy),
// we sample a fixed number of random pairs from the precomputed 2048 neuron positions.
// With a small chance (here 2%), a connection is added.
void checkAndAddConnections() {
  int totalNeurons = allNeuronPositions.length;
  int sampleCount = 100;  // number of random pairs to test per frame
  float p = 0.02;       // 2% chance to add a connection
  float maxDist = 1200;  // generous threshold (covers the entire grid)
  
  for (int i = 0; i < sampleCount; i++) {
    int idx1 = int(random(totalNeurons));
    int idx2 = int(random(totalNeurons));
    if (idx1 == idx2) continue;
    PVector p1 = allNeuronPositions[idx1];
    PVector p2 = allNeuronPositions[idx2];
    if (PVector.dist(p1, p2) < maxDist) {
      if (random(1) < p) {
        // Use activeColor but later the connection opacity is applied when drawing.
        connections.add(new Connection(p1.copy(), p2.copy(), activeColor));
      }
    }
  }
}

// ---------------- Draw connections and remove expired ones ----------------
// Each connection is drawn as a line with its stored color but with the current global connectionOpacity.
// Connections older than 5 seconds are removed.
void drawConnections() {
  float currentTime = millis();
  for (int i = connections.size()-1; i >= 0; i--) {
    Connection conn = connections.get(i);
    if (currentTime - conn.createdTime > 5000) {  // lifetime of 5 seconds
      connections.remove(i);
    } else {
      // Override the stored alpha with the current connectionOpacity.
      stroke(red(conn.col), green(conn.col), blue(conn.col), connectionOpacity);
      strokeWeight(2);
      line(conn.start.x, conn.start.y, conn.start.z, conn.end.x, conn.end.y, conn.end.z);
    }
  }
}

// ---------------- Monome grid button press handler ----------------
// When a grid button is pressed (s==1), disable its randomization and increment its brightness.
public void key(int x, int y, int s) {
  if (s == 1) {
    if (isRandom[y][x]) {
      isRandom[y][x] = false;  // Stop random updates on this cell
    }
    grid_led[y][x] = (grid_led[y][x] + 1) % 16;
    grid_dirty = true;
  }
}

// ---------------- Encoder (arc) key handler ----------------
// Mapping for four encoders:
// • Encoder 0: On click, change the resting neuron base color (RGB), preserving its alpha.
// • Encoder 1: On click, change the active neuron base color (RGB), preserving its alpha.
// • Encoder 2: On click, change the background base color (RGB), preserving its alpha.
// • Encoder 3: On click, (optionally) can be used for other behavior; here we simply print a message.
public void key(int n, int s) {
  if (s == 1) {
    if (n == 0) {
      float currentAlpha = alpha(restingColor);
      restingColor = color(random(255), random(255), random(255), currentAlpha);
      println("Encoder 0 pressed. Changing resting neuron base color.");
    } else if (n == 1) {
      float currentAlpha = alpha(activeColor);
      activeColor = color(random(255), random(255), random(255), currentAlpha);
      println("Encoder 1 pressed. Changing active neuron base color.");
    } else if (n == 2) {
      float currentAlpha = alpha(bgColor);
      bgColor = color(random(255), random(255), random(255), currentAlpha);
      println("Encoder 2 pressed. Changing background base color.");
    } else if (n == 3) {
      println("Encoder 3 pressed. Connection opacity control active.");
    } else {
      println("Encoder " + n + " pressed. Generating new shape/position.");
      objectTypes[n] = int(random(4));
      objectColors[n] = color(random(255), random(255), random(255));
      objectPositions[n] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
      bgColor = color(random(255), random(255), random(255));
    }
  }
}

// ---------------- Encoder (arc) delta handler ----------------
// When an encoder is turned, update its position and then update the arc LEDs.
// For encoders 0, 1, and 2, adjust the corresponding transparency as before.
// For encoder 3, update the connection opacity.
public void delta(int n, int d) {
  arc_positions[n] += d;
  arc_positions[n] = constrain(arc_positions[n], 0, arc_numLeds);
  arc_dirty = true;
}

// ---------------- Update arc LEDs and adjust transparency ----------------
// This function lights up the arc LEDs based on the current encoder value.
// • Encoder 0: Maps its value to resting neurons' alpha (20–200).
// • Encoder 1: Maps to active neurons' alpha (200–255).
// • Encoder 2: Maps to background alpha (50–255).
// • Encoder 3: Maps to connection opacity (0–255).
public void update_arc_leds(int encoderIndex) {
  int[] led = new int[arc_numLeds];
  for (int i = 0; i < arc_positions[encoderIndex]; i++) {
    led[i] = 15;
  }
  a.refresh(encoderIndex, led);
  
  if (encoderIndex == 0) {
    float newAlpha = map(arc_positions[0], 0, 64, 20, 200);
    restingColor = color(red(restingColor), green(restingColor), blue(restingColor), newAlpha);
  } else if (encoderIndex == 1) {
    float newAlpha = map(arc_positions[1], 0, 64, 200, 255);
    activeColor = color(red(activeColor), green(activeColor), blue(activeColor), newAlpha);
  } else if (encoderIndex == 2) {
    float newAlpha = map(arc_positions[2], 0, 64, 50, 255);
    bgColor = color(red(bgColor), green(bgColor), blue(bgColor), newAlpha);
  } else if (encoderIndex == 3) {
    connectionOpacity = map(arc_positions[3], 0, 64, 0, 255);
  }
}

// ---------------- Retained functions for topographic shapes and tunnel ----------------
void updateFrequency(int objIndex, int axis) {
  float normalizedPosition = faderPositions[objIndex][axis] / 7.0;
  float faderValue = minFreq * pow((maxFreq / minFreq), normalizedPosition);
  if (axis == 0) freqX[objIndex] = faderValue;
  if (axis == 1) freqY[objIndex] = faderValue;
  if (axis == 2) freqZ[objIndex] = faderValue;
  for (int y = 0; y < 8; y++) {
    int ledValue = (y >= (7 - faderPositions[objIndex][axis])) ? 15 : 0;
    int gridColumn = objIndex * 4 + axis;
    grid_led[y][gridColumn] = ledValue;
  }
}

void updateOscillation(int objIndex) {
  float faderValue = map(oscillationFaderPositions[objIndex], 0, 7, minOscillationAmplitude, maxOscillationAmplitude);
  oscillationAmplitudes[objIndex] = faderValue;
  for (int y = 0; y < 8; y++) {
    int ledValue = (y >= (7 - oscillationFaderPositions[objIndex])) ? 15 : 0;
    int gridColumn = objIndex * 4 + 3;
    grid_led[y][gridColumn] = ledValue;
  }
}

void drawInfiniteTunnel() {
  // (Original tunnel drawing code)
}

public void drawPlaneLikeShape(int type, float planeSize, color objColor) {
  stroke(objColor);
  fill(objColor, 100);
  switch(type) {
    case 0:
      topographicSwirlPlane(planeSize);
      break;
    case 1:
      topographicRadialWaveDisc(planeSize);
      break;
    case 2:
      topographicLayeredRidgePlane(planeSize);
      break;
    case 3:
      topographicRipplePlane(planeSize);
      break;
  }
}

void topographicSwirlPlane(float planeSize) {
  // (Original code for swirl plane)
}

void topographicRadialWaveDisc(float discSize) {
  // (Original code for radial wave disc)
}

void topographicLayeredRidgePlane(float planeSize) {
  // (Original code for layered ridge plane)
}

void topographicRipplePlane(float planeSize) {
  // (Original code for ripple plane)
}
