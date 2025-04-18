import org.monome.Monome;
import oscP5.*;
import netP5.*;

Monome g;
int[][] grid_led = new int[8][16]; 
boolean grid_dirty = true;

Monome a;
int arc_numLeds = 64;
int[] arc_led = new int[arc_numLeds];
int[] arc_positions = new int[4];
boolean arc_dirty = true;

// Four objects (3 new plane-like shapes + 1 old ripple plane)
PVector[] objectPositions = new PVector[4]; 
int[] objectTypes = new int[4];  // 0=SwirlPlane, 1=RadialWaveDisc, 2=LayeredRidgePlane, 3=RipplePlane
color[] objectColors = new color[4];
float maxObjectSize = 750; 
color bgColor = color(0);

// Rotation / oscillation controls
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

// OSC
OscP5 oscP5;

// Infinite noise tunnel parameters
int tunnelRings = 80;      
int ringResolution = 48;   
float ringSpacing = 80;    
float baseRadius = 1000;    
float noiseAmplitude = 40; 
float noiseScale = 0.05;   
float tunnelSpeed = 100;    
float tunnelOffset = 0;    

public void setup() {
  size(1560, 1400, P3D);
  g = new Monome(this, "m29496721");
  a = new Monome(this, "m0000007");

  // Initialize OSC listening on port 8000
  oscP5 = new OscP5(this, 3333);

  // Initialize our 4 plane-like topographic shapes
  for (int i = 0; i < 4; i++) {
    objectPositions[i] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
    // 4 shapes: 0=SwirlPlane, 1=RadialWaveDisc, 2=LayeredRidgePlane, 3=RipplePlane
    objectTypes[i] = int(random(4));  
    objectColors[i] = color(random(255), random(255), random(255));

    // Set up default rotation frequencies
    for (int j = 0; j < 3; j++) {
      faderPositions[i][j] = 4; 
      updateFrequency(i, j);
    }
    // Set up default oscillation
    oscillationFaderPositions[i] = 4; 
    updateOscillation(i);
  }
}

public void draw() {
  background(bgColor);

  // Draw infinite noise tunnel
  pushMatrix();
    translate(width/2, height/2, 0);
    drawInfiniteTunnel();
  popMatrix();

  // Draw the four topographic plane-like shapes
  for (int i = 0; i < 4; i++) {
    float oscillation = sin(millis() * oscillationSpeed) * oscillationAmplitudes[i];
    pushMatrix();
      translate(objectPositions[i].x, objectPositions[i].y, objectPositions[i].z + oscillation);

      rotateX(sin(millis() * freqX[i]) * PI);
      rotateY(cos(millis() * freqY[i]) * PI);
      rotateZ(sin(millis() * freqZ[i]) * PI);

      float size = map(arc_positions[i], 0, arc_numLeds, 50, maxObjectSize);
      drawPlaneLikeShape(objectTypes[i], size, objectColors[i]);
    popMatrix();
  }

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

// -----------------------------------------------------------------
// MONOME + ARC + OSC HANDLERS
// -----------------------------------------------------------------

public void key(int x, int y, int s) {
  if (s == 1) {
    int objectIndex = x / 4;
    int axis = x % 4;
    if (axis >= 0 && axis <= 3 && objectIndex < 4) {
      int faderPosition = y;
      if (axis <= 2) {
        faderPositions[objectIndex][axis] = 7 - faderPosition; 
        updateFrequency(objectIndex, axis);
      } else if (axis == 3) {
        oscillationFaderPositions[objectIndex] = 7 - faderPosition; 
        updateOscillation(objectIndex);
      }
      grid_dirty = true;
    }
  }
}

public void delta(int n, int d) {
  arc_positions[n] += d;
  arc_positions[n] = constrain(arc_positions[n], 0, arc_numLeds);
  arc_dirty = true;
}

public void key(int n, int s) {
  if (s == 1) {
    println("Encoder " + n + " pressed. Generating new shape/position.");
    objectTypes[n] = int(random(4));  // pick from the 4 plane-like shapes
    objectColors[n] = color(random(255), random(255), random(255));
    objectPositions[n] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
    bgColor = color(random(255), random(255), random(255));
  }
}

void oscEvent(OscMessage msg) {
  int randomEncoder = int(random(4)); 
  key(randomEncoder, 1); 
}

public void update_arc_leds(int encoderIndex) {
  int[] led = new int[arc_numLeds];
  for (int i = 0; i < arc_positions[encoderIndex]; i++) {
    led[i] = 15;
  }
  a.refresh(encoderIndex, led);
}

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

// -----------------------------------------------------------------
// INFINITE NOISE TUNNEL BACKGROUND
// -----------------------------------------------------------------
void drawInfiniteTunnel() {
  tunnelOffset += tunnelSpeed;

  stroke(150, 100);
  noFill();

  for (int i = 0; i < tunnelRings; i++) {
    int ringIndex = floor(tunnelOffset / ringSpacing) + i;
    int nextRingIndex = ringIndex + 1;

    float z1 = -(ringIndex * ringSpacing - tunnelOffset);
    float z2 = -(nextRingIndex * ringSpacing - tunnelOffset);

    beginShape(TRIANGLE_STRIP);
    for (int r = 0; r <= ringResolution; r++) {
      float angle = map(r, 0, ringResolution, 0, TWO_PI);

      float radius1 = baseRadius + noise(
        cos(angle) * noiseScale + ringIndex * 0.1,
        sin(angle) * noiseScale + ringIndex * 0.1
      ) * noiseAmplitude;
      float x1 = radius1 * cos(angle);
      float y1 = radius1 * sin(angle);

      float radius2 = baseRadius + noise(
        cos(angle) * noiseScale + nextRingIndex * 0.1,
        sin(angle) * noiseScale + nextRingIndex * 0.1
      ) * noiseAmplitude;
      float x2 = radius2 * cos(angle);
      float y2 = radius2 * sin(angle);

      vertex(x1, y1, z1);
      vertex(x2, y2, z2);
    }
    endShape();
  }
}

// -----------------------------------------------------------------
// 4 PLANE-LIKE TOPOGRAPHIC SHAPES
// -----------------------------------------------------------------
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
      topographicRipplePlane(planeSize); // the original
      break;
  }
}

// 1) Swirl Plane
//   Similar to a subdivided plane, but each vertex has an additional swirl distortion
void topographicSwirlPlane(float planeSize) {
  int planeResolution = 40;
  float halfSize = planeSize * 0.5;
  float step = planeSize / planeResolution;
  float time = millis() * 0.0003;

  for (int z = 0; z < planeResolution; z++) {
    beginShape(TRIANGLE_STRIP);
    for (int x = 0; x <= planeResolution; x++) {
      // We'll compute world coords for two "rows": z and z+1
      float px1 = x * step - halfSize;
      float pz1 = z * step - halfSize;
      float px2 = x * step - halfSize;
      float pz2 = (z+1) * step - halfSize;

      // Distort y by noise (like ripple plane)
      float nVal1 = noise(px1*0.01 + time, pz1*0.01 - time);
      float y1 = map(nVal1, 0,1, -planeSize*0.2, planeSize*0.2);
      float nVal2 = noise(px2*0.01 - time, pz2*0.01 + time);
      float y2 = map(nVal2, 0,1, -planeSize*0.2, planeSize*0.2);

      // Add swirl distortion around plane center
      float swirlFactor1 = 0.002 * planeSize;  // swirl intensity
      float angle1 = swirlFactor1 * dist(px1, pz1, 0,0); // swirl angle depends on distance from center
      float rotatedX1 = px1*cos(angle1) - pz1*sin(angle1);
      float rotatedZ1 = px1*sin(angle1) + pz1*cos(angle1);

      float swirlFactor2 = swirlFactor1;
      float angle2 = swirlFactor2 * dist(px2, pz2, 0,0);
      float rotatedX2 = px2*cos(angle2) - pz2*sin(angle2);
      float rotatedZ2 = px2*sin(angle2) + pz2*cos(angle2);

      vertex(rotatedX1, y1, rotatedZ1);
      vertex(rotatedX2, y2, rotatedZ2);
    }
    endShape();
  }
}

// 2) Radial Wave Disc
//   A circular disc subdivided into radial rings, each vertex is noise-distorted
void topographicRadialWaveDisc(float discSize) {
  int rings = 40;
  int sectors = 40;
  float radius = discSize * 0.5;
  float time = millis() * 0.0003;

  // We'll draw each ring as a TRIANGLE_STRIP connecting ring i to ring i+1
  for (int r = 0; r < rings; r++) {
    float ringRadius1 = map(r, 0, rings, 0, radius);
    float ringRadius2 = map(r+1, 0, rings, 0, radius);

    beginShape(TRIANGLE_STRIP);
    for (int s = 0; s <= sectors; s++) {
      float angle = map(s, 0, sectors, 0, TWO_PI);

      // ring 1
      float x1 = ringRadius1 * cos(angle);
      float z1 = ringRadius1 * sin(angle);
      float nVal1 = noise(x1*0.01+time, z1*0.01-time);
      float y1 = map(nVal1, 0,1, -discSize*0.2, discSize*0.2);

      // ring 2
      float x2 = ringRadius2 * cos(angle);
      float z2 = ringRadius2 * sin(angle);
      float nVal2 = noise(x2*0.01-time, z2*0.01+time);
      float y2 = map(nVal2, 0,1, -discSize*0.2, discSize*0.2);

      vertex(x1, y1, z1);
      vertex(x2, y2, z2);
    }
    endShape();
  }
}

// 3) Layered Ridge Plane
//   Another plane-like shape but arranged in concentric “layers,” reminiscent of topographic lines
void topographicLayeredRidgePlane(float planeSize) {
  int layers = 30;   // how many ridges
  float halfSize = planeSize * 0.5;
  float step = planeSize / layers;
  float time = millis() * 0.0002;

  // We'll treat each "layer" as a "ring" from -size/2 to +size/2
  // We'll do a shape that’s basically a set of squares inside each other, each distorted in y
  for (int i = 0; i < layers; i++) {
    float layerFrac1 = i/(float)layers;
    float layerFrac2 = (i+1)/(float)layers;

    float outSize1 = lerp(0, halfSize, layerFrac1);
    float outSize2 = lerp(0, halfSize, layerFrac2);

    beginShape(TRIANGLE_STRIP);
    // We'll approximate a square "ring" by connecting corners in a loop
    // But for smoothness, let's do more segments.
    int segCount = 40;
    for (int s = 0; s <= segCount; s++) {
      float angle = map(s, 0, segCount, 0, TWO_PI);

      float x1 = outSize1 * cos(angle);
      float z1 = outSize1 * sin(angle);
      float nVal1 = noise(x1*0.01+time, z1*0.01-time);
      float y1 = map(nVal1, 0,1, -planeSize*0.2, planeSize*0.2);

      float x2 = outSize2 * cos(angle);
      float z2 = outSize2 * sin(angle);
      float nVal2 = noise(x2*0.01-time, z2*0.01+time);
      float y2 = map(nVal2, 0,1, -planeSize*0.2, planeSize*0.2);

      vertex(x1, y1, z1);
      vertex(x2, y2, z2);
    }
    endShape();
  }
}

// 4) The original Topographic Ripple Plane (unchanged from prior code)
void topographicRipplePlane(float planeSize) {
  int planeResolution = 40;  
  float halfSize = planeSize * 0.5;
  float step = planeSize / planeResolution;
  float time = millis() * 0.0002;

  for (int z = 0; z < planeResolution; z++) {
    beginShape(TRIANGLE_STRIP);
    for (int x = 0; x <= planeResolution; x++) {
      float worldX1 = x * step - halfSize;
      float worldZ1 = z * step - halfSize;
      float nVal1 = noise(worldX1*0.01 + time, worldZ1*0.01 - time);
      float y1 = map(nVal1, 0,1, -planeSize*0.2, planeSize*0.2);

      float worldX2 = x * step - halfSize;
      float worldZ2 = (z+1) * step - halfSize;
      float nVal2 = noise(worldX2*0.01 - time, worldZ2*0.01 + time);
      float y2 = map(nVal2, 0,1, -planeSize*0.2, planeSize*0.2);

      vertex(worldX1, y1, worldZ1);
      vertex(worldX2, y2, worldZ2);
    }
    endShape();
  }
}
