import org.monome.Monome;
import oscP5.*;

Monome g;
int[][] grid_led = new int[8][16]; // Adjusted for 8 rows and 16 columns
boolean grid_dirty = true;

Monome a;
int arc_numLeds = 64;
int[] arc_led = new int[arc_numLeds];
int[] arc_positions = new int[4];
boolean arc_dirty = true;

PVector[] objectPositions = new PVector[4]; 
float[] animationSpeeds = {1.0, 0.8, 0.5, 0.2};
int[] objectTypes = new int[4]; // Track each object type: 0 = icosahedron, 1 = sphere, 2 = torus, 3 = helix, 4 = mobius
color[] objectColors = new color[4];
float maxObjectSize = 750; // Increased max size for larger objects
color bgColor = color(0);
// float oscillationSpeed = 0.10; // Moved to per-object if desired

// Define arrays for each axis rotation angle and unique frequency for each object
float[] freqX = new float[4];
float[] freqY = new float[4];
float[] freqZ = new float[4];
int[][] faderPositions = new int[4][3]; // Stores positions for 4 objects, 3 axes (X, Y, Z)
float maxFreq = 0.007;   // Maximum rotation frequency
float minFreq = 0.00005; // Adjusted minimum rotation frequency for slower rotation

// For oscillation control
int[] oscillationFaderPositions = new int[4]; // Stores fader positions for oscillation amplitude per object
float[] oscillationAmplitudes = new float[4]; // Per-object oscillation amplitude
float minOscillationAmplitude = 0;   // Minimum oscillation amplitude (no oscillation)
float maxOscillationAmplitude = 200; // Maximum oscillation amplitude
float oscillationSpeed = 0.10;       // Oscillation speed (shared among objects)

public void setup() {
  size(2560, 1400, P3D); //860,600 for PAS
  g = new Monome(this, "m29496721");
  a = new Monome(this, "m0000007");

  for (int i = 0; i < 4; i++) {
    objectPositions[i] = new PVector(random(200, width - 200), random(200, height - 200), random(-100, 100));
    objectTypes[i] = int(random(5));
    objectColors[i] = color(random(255), random(255), random(255));

    for (int j = 0; j < 3; j++) {
      faderPositions[i][j] = 4; // Initialize rotation fader to mid-point (0 to 7)
      updateFrequency(i, j);     // Update frequency based on fader position
    }

    oscillationFaderPositions[i] = 4; // Initialize oscillation fader to mid-point
    updateOscillation(i);             // Update oscillation amplitude
  }
}

public void key(int x, int y, int s) {
  if (s == 1) {
    int objectIndex = x / 4;
    int axis = x % 4;
    if (axis >= 0 && axis <= 3 && objectIndex < 4) {
      int faderPosition = y;
      if (axis <= 2) {
        // Existing code for rotation axes
        faderPositions[objectIndex][axis] = 7 - faderPosition; // Invert to have fader increase upwards
        updateFrequency(objectIndex, axis);
      } else if (axis == 3) {
        // New code for oscillation amplitude control
        oscillationFaderPositions[objectIndex] = 7 - faderPosition; // Invert for upward increase
        updateOscillation(objectIndex);
      }
      grid_dirty = true;
    }
  }
}

void updateFrequency(int objIndex, int axis) {
  // Exponential mapping for smoother control
  float normalizedPosition = faderPositions[objIndex][axis] / 7.0; // Normalize to range 0.0 - 1.0
  float faderValue = minFreq * pow((maxFreq / minFreq), normalizedPosition); // Exponential scaling

  if (axis == 0) freqX[objIndex] = faderValue;
  if (axis == 1) freqY[objIndex] = faderValue;
  if (axis == 2) freqZ[objIndex] = faderValue;

  // Update LEDs to display fader level
  for (int y = 0; y < 8; y++) {
    int ledValue = (y >= (7 - faderPositions[objIndex][axis])) ? 15 : 0;
    int gridColumn = objIndex * 4 + axis;
    grid_led[y][gridColumn] = ledValue;
  }
}

void updateOscillation(int objIndex) {
  // Map fader position to oscillation amplitude
  float faderValue = map(oscillationFaderPositions[objIndex], 0, 7, minOscillationAmplitude, maxOscillationAmplitude);
  oscillationAmplitudes[objIndex] = faderValue;

  // Update LEDs to display fader level
  for (int y = 0; y < 8; y++) {
    int ledValue = (y >= (7 - oscillationFaderPositions[objIndex])) ? 15 : 0;
    int gridColumn = objIndex * 4 + 3; // Column for oscillation control
    grid_led[y][gridColumn] = ledValue;
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

public void update_arc_leds(int encoderIndex) {
  int[] led = new int[arc_numLeds];
  for (int i = 0; i < arc_positions[encoderIndex]; i++) {
    led[i] = 15;
  }
  a.refresh(encoderIndex, led);
}

public void drawObject(int type, float size, color objColor) {
  stroke(objColor);
  noFill();
  switch(type) {
    case 0:
      icosahedron(size / 2); // Replaces box with icosahedron
      break;
    case 1:
      sphere(size / 2);
      break;
    case 2:
      torus(size / 4, size / 8);
      break;
    case 3:
      helix(size / 2, 10, objColor); // Helix shape
      break;
    case 4:
      mobius(size / 3, objColor); // Mobius strip shape
      break;
  }
}

public void draw() {
  background(bgColor);

  for (int i = 0; i < 4; i++) {
    float oscillation = sin(millis() * oscillationSpeed) * oscillationAmplitudes[i];

    pushMatrix();
    translate(objectPositions[i].x, objectPositions[i].y, objectPositions[i].z + oscillation);

    // Apply unique rotational loops on each axis
    rotateX(sin(millis() * freqX[i]) * PI); // X-axis
    rotateY(cos(millis() * freqY[i]) * PI); // Y-axis
    rotateZ(sin(millis() * freqZ[i]) * PI); // Z-axis

    float size = map(arc_positions[i], 0, arc_numLeds, 50, maxObjectSize);
    drawObject(objectTypes[i], size, objectColors[i]);
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

// Icosahedron shape function
void icosahedron(float r) {
  float t = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio

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

  scale(r);
  beginShape(TRIANGLES);
  for (int[] face : faces) {
    for (int vertexIndex : face) {
      PVector v = vertices[vertexIndex];
      vertex(v.x, v.y, v.z);
    }
  }
  endShape();
}

void helix(float radius, int coils, color c) {
  stroke(c);
  float angleStep = PI / 15;
  float heightStep = radius / coils;
  beginShape();
  for (float angle = 0; angle < TWO_PI * coils; angle += angleStep) {
    float x = radius * cos(angle);
    float y = radius * sin(angle);
    float z = angle * heightStep;
    vertex(x, y, z);
  }
  endShape();
}

void mobius(float size, color c) {
  stroke(c);
  float width = size / 5;
  beginShape(TRIANGLE_STRIP);
  for (float v = -PI; v < PI; v += 0.05) {
    for (int side = -1; side <= 1; side += 2) {
      float u = v * side;
      float x = size * cos(u) * (1 + 0.5 * cos(v));
      float y = size * sin(u) * (1 + 0.5 * cos(v));
      float z = width * sin(v);
      vertex(x, y, z);
    }
  }
  endShape();
}

void torus(float r, float tube) {
  int res = 24;
  for (int i = 0; i < res; i++) {
    float theta = TWO_PI * i / res;
    float nextTheta = TWO_PI * (i + 1) / res;
    beginShape(TRIANGLE_STRIP);
    for (int j = 0; j <= res; j++) {
      float phi = TWO_PI * j / res;
      float cosPhi = cos(phi);
      float sinPhi = sin(phi);

      PVector p1 = new PVector((r + tube * cosPhi) * cos(theta), (r + tube * cosPhi) * sin(theta), tube * sinPhi);
      PVector p2 = new PVector((r + tube * cosPhi) * cos(nextTheta), (r + tube * cosPhi) * sin(nextTheta), tube * sinPhi);

      vertex(p1.x, p1.y, p1.z);
      vertex(p2.x, p2.y, p2.z);
    }
    endShape();
  }
}
