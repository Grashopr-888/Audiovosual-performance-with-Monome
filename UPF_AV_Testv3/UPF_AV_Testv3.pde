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

PVector[] objectPositions = new PVector[4]; 
float[] animationSpeeds = {1.0, 0.8, 0.5, 0.2};
int[] objectTypes = new int[4]; 
color[] objectColors = new color[4];
float maxObjectSize = 750; 
color bgColor = color(0);

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

// Increased resolution & faster wave speed
int terrainCols = 200;   
int terrainRows = 200;
float terrainScale = 15;  
float terrainHeight = 200;
float terrainNoiseOffset = 0;
// Increase speed for more dramatic background waves
float terrainNoiseSpeed = 0.0025;

public void setup() {
  size(1560, 1400, P3D);
  g = new Monome(this, "m29496721");
  a = new Monome(this, "m0000007");

  // Initialize OSC listening on port 8000
  oscP5 = new OscP5(this, 8000);

  for (int i = 0; i < 4; i++) {
    objectPositions[i] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
    objectTypes[i] = int(random(5)); // 0=icosahedron,1=sphere,2=torus,3=helix,4=mobius
    objectColors[i] = color(random(255), random(255), random(255));

    for (int j = 0; j < 3; j++) {
      faderPositions[i][j] = 4; 
      updateFrequency(i, j);
    }
    oscillationFaderPositions[i] = 4; 
    updateOscillation(i);
  }
}

public void draw() {
  background(bgColor);

  // Draw topographic surface across the entire canvas
  pushMatrix();
    translate(width*0.5, height*0.65, -400);  
    rotateX(PI/3.0);
    drawTopographicBackground();
  popMatrix();

  // Draw the 4 objects with partial fill + wireframe edges
  for (int i = 0; i < 4; i++) {
    float oscillation = sin(millis() * oscillationSpeed) * oscillationAmplitudes[i];
    pushMatrix();
      translate(objectPositions[i].x, objectPositions[i].y, objectPositions[i].z + oscillation);

      rotateX(sin(millis() * freqX[i]) * PI);
      rotateY(cos(millis() * freqY[i]) * PI);
      rotateZ(sin(millis() * freqZ[i]) * PI);

      float size = map(arc_positions[i], 0, arc_numLeds, 50, maxObjectSize);
      drawObjectTopographicFilled(objectTypes[i], size, objectColors[i]);
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

// --------------------------------------------------------------
// MONOME + ARC + OSC HANDLERS
// --------------------------------------------------------------

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
    println("Encoder " + n + " pressed. Generating new object.");
    objectTypes[n] = int(random(5));
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

// --------------------------------------------------------------
// DRAWING: TOPOGRAPHIC BACKGROUND & FILLED SHAPES
// --------------------------------------------------------------

// Faster, more dynamic background waves
void drawTopographicBackground() {
  terrainNoiseOffset += terrainNoiseSpeed;  
  float yOff = terrainNoiseOffset;

  stroke(150, 100);
  noFill();

  for (int z = 0; z < terrainRows - 1; z++) {
    beginShape(TRIANGLE_STRIP);
    float xOff = 0;
    for (int x = 0; x < terrainCols; x++) {
      float nx1 = noise(xOff, yOff + z * 0.1);
      float nx2 = noise(xOff, yOff + (z+1) * 0.1);

      float worldX = (x - terrainCols/2) * terrainScale;
      float worldZ1 = (z - terrainRows/2) * terrainScale;
      float worldZ2 = ((z+1) - terrainRows/2) * terrainScale;

      float h1 = nx1 * terrainHeight;
      float h2 = nx2 * terrainHeight;

      vertex(worldX, -h1, worldZ1);
      vertex(worldX, -h2, worldZ2);

      xOff += 0.1;
    }
    endShape();
  }
}

// Draw 4 shapes with partial fill + topographic distortion
public void drawObjectTopographicFilled(int type, float size, color objColor) {
  // We'll use the object color for both fill and stroke to make them visible
  stroke(objColor);
  fill(objColor, 100);  // semi-transparent fill

  switch(type) {
    case 0: // Icosahedron
      drawTopographicIcosahedron(size * 0.5);
      break;
    case 1: // Sphere
      drawTopographicSphere(size * 0.5);
      break;
    case 2: // Torus
      drawTopographicTorus(size * 0.5, size * 0.15);
      break;
    case 3: // Helix
      drawTopographicHelix(size * 0.5, 10, objColor);
      break;
    case 4: // Mobius
      drawTopographicMobius(size * 0.4, objColor);
      break;
  }
}

// --------------------------------------------------------------
// TOPOGRAPHIC SHAPE FUNCTIONS (with noise distortion)
// --------------------------------------------------------------
void drawTopographicIcosahedron(float r) {
  float t = (1.0 + sqrt(5.0)) / 2.0; 
  PVector[] vertices = {
    new PVector(-1, t, 0), new PVector(1, t, 0), new PVector(-1, -t, 0), new PVector(1, -t, 0),
    new PVector(0, -1, t), new PVector(0, 1, t), new PVector(0, -1, -t), new PVector(0, 1, -t),
    new PVector(t, 0, -1), new PVector(t, 0, 1), new PVector(-t, 0, -1), new PVector(-t, 0, 1)
  };

  int[][] faces = {
    {0, 11, 5}, {0, 5, 1}, {0, 1, 7}, {0, 7, 10}, {0, 10, 11},
    {1, 5, 9}, {5, 11, 4}, {11, 10, 2}, {10, 7, 6}, {7, 1, 8},
    {3, 9, 4}, {3, 4, 2}, {3, 2, 6}, {3, 6, 8}, {3, 8, 9},
    {4, 9, 5}, {2, 4, 11}, {6, 2, 10}, {8, 6, 7}, {9, 8, 1}
  };

  float time = millis() * 0.0002;
  PVector[] distorted = new PVector[vertices.length];
  for (int i = 0; i < vertices.length; i++) {
    PVector v = vertices[i].copy();
    v.normalize();
    v.mult(r);
    float nVal = noise(v.x*0.01 + time, v.y*0.01 + time, v.z*0.01 + time);
    float distortion = map(nVal, 0, 1, 0, r * 0.3);
    v.mult(1 + (distortion / r));
    distorted[i] = v;
  }

  // Now we draw the faces as triangles (filled)
  for (int[] face : faces) {
    beginShape(TRIANGLES);
    for (int vertexIndex : face) {
      PVector dv = distorted[vertexIndex];
      vertex(dv.x, dv.y, dv.z);
    }
    endShape(CLOSE);
  }
}

void drawTopographicSphere(float r) {
  int detail = 24;
  float time = millis() * 0.0003;
  // We'll draw lat/long strips; each strip gets filled
  for (int i = 0; i < detail; i++) {
    float lat0 = map(i, 0, detail, -HALF_PI, HALF_PI);
    float lat1 = map(i+1, 0, detail, -HALF_PI, HALF_PI);

    beginShape(TRIANGLE_STRIP);
    for (int j = 0; j <= detail; j++) {
      float lon = map(j, 0, detail, 0, TWO_PI);

      PVector p1 = sphericalToCartesian(r, lat0, lon);
      PVector p2 = sphericalToCartesian(r, lat1, lon);

      float d1 = noise(p1.x*0.01 + time, p1.y*0.01, p1.z*0.01) * (r*0.3);
      float d2 = noise(p2.x*0.01 - time, p2.y*0.01, p2.z*0.01) * (r*0.3);
      p1.mult(1 + d1 / r);
      p2.mult(1 + d2 / r);

      vertex(p1.x, p1.y, p1.z);
      vertex(p2.x, p2.y, p2.z);
    }
    endShape();
  }
}

PVector sphericalToCartesian(float radius, float lat, float lon) {
  float x = radius * cos(lat) * cos(lon);
  float y = radius * cos(lat) * sin(lon);
  float z = radius * sin(lat);
  return new PVector(x, y, z);
}

void drawTopographicTorus(float R, float r) {
  int res = 48;
  float time = millis() * 0.0004;
  
  for (int i = 0; i < res; i++) {
    float theta = TWO_PI * i / res;
    float nextTheta = TWO_PI * (i+1) / res;
    beginShape(TRIANGLE_STRIP);
    for (int j = 0; j <= res; j++) {
      float phi = TWO_PI * j / res;

      PVector p1 = torusPoint(R, r, theta, phi);
      PVector p2 = torusPoint(R, r, nextTheta, phi);

      float d1 = noise(p1.x*0.005 + time, p1.y*0.005, p1.z*0.005) * (r*0.8);
      float d2 = noise(p2.x*0.005 - time, p2.y*0.005, p2.z*0.005) * (r*0.8);
      p1.mult(1 + d1 / (R + r));
      p2.mult(1 + d2 / (R + r));
      
      vertex(p1.x, p1.y, p1.z);
      vertex(p2.x, p2.y, p2.z);
    }
    endShape();
  }
}

PVector torusPoint(float R, float r, float theta, float phi) {
  float x = (R + r*cos(phi)) * cos(theta);
  float y = (R + r*cos(phi)) * sin(theta);
  float z = r * sin(phi);
  return new PVector(x, y, z);
}

void drawTopographicHelix(float radius, int coils, color c) {
  float angleStep = PI / 15;
  float heightStep = radius / coils;
  float time = millis() * 0.0002;

  // We'll fill each coil section with TRIANGLE_STRIP to create a “tube-like” helix
  // For simplicity, let's just create multiple rings along the helix path
  beginShape(TRIANGLE_STRIP);
  for (float angle = 0; angle < TWO_PI * coils; angle += angleStep) {
    float x = radius * cos(angle);
    float y = radius * sin(angle);
    float z = angle * heightStep;

    float d = noise(x*0.01 + time, y*0.01, z*0.01) * (radius * 0.3);
    PVector v = new PVector(x, y, z);
    v.mult(1 + d / radius);
    vertex(v.x, v.y, v.z);

    // An offset second vertex to give “thickness” 
    float angleOffset = angle + 0.05;
    float x2 = radius * cos(angleOffset);
    float y2 = radius * sin(angleOffset);
    float z2 = angleOffset * heightStep;
    float d2 = noise(x2*0.01 - time, y2*0.01, z2*0.01) * (radius * 0.3);
    PVector v2 = new PVector(x2, y2, z2);
    v2.mult(1 + d2 / radius);
    vertex(v2.x, v2.y, v2.z);
  }
  endShape();
}

void drawTopographicMobius(float size, color c) {
  float width = size / 5;
  float step = 0.05;
  float time = millis() * 0.0003;

  beginShape(TRIANGLE_STRIP);
  for (float v = -PI; v < PI; v += step) {
    for (int side = -1; side <= 1; side += 2) {
      float u = v * side;
      float x = size * cos(u) * (1 + 0.5 * cos(v));
      float y = size * sin(u) * (1 + 0.5 * cos(v));
      float z = width * sin(v);

      float d = noise(x*0.01 - time, y*0.01 + time, z*0.01) * (size * 0.2);
      PVector p = new PVector(x, y, z);
      p.mult(1 + d / size);

      vertex(p.x, p.y, p.z);
    }
  }
  endShape();
}
