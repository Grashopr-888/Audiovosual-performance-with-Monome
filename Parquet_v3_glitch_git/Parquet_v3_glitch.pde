import oscP5.*;
import netP5.*;
import ddf.minim.*;
import org.monome.Monome;

Monome m;
boolean dirty;

int[][] step;
int timer;
int play_position;
int loop_start, loop_end;
int STEP_TIME = 5;
boolean cutting;
int next_position;
int keys_held, key_last;

int cols, rows;
int scl = 20;
float w, h;
float[][] z, z_bg;
float[][] objectPositions;
color[] stepColors;

Minim minim;
AudioPlayer player;
OscP5 oscP5;

float deformSpeed = 0.04; // Speed of plane deformation
float brightness = 1.0;   // Brightness of the animation
float scale = 1.0;        // Scale of the animation

void setup() {
  size(2560, 1400, P3D); // Double the canvas size
  cols = width / scl;
  rows = height / scl;
  w = width;
  h = height;
  z = new float[cols][rows];
  z_bg = new float[cols][rows];
  noiseDetail(8, 0.65); // Increased persistence to maintain pattern complexity

  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      z[i][j] = noise(i * 0.1, j * 0.1) * 2 - 1; // Increase noise range for more complexity
      z_bg[i][j] = noise(i * 0.1 + 100, j * 0.1 + 100) * 2 - 1;
    }
  }

  objectPositions = new float[10][2];
  for (int i = 0; i < 10; i++) {
    objectPositions[i][0] = random(-300, 300); // x position
    objectPositions[i][1] = random(-100, 100); // y position
  }

  // Initialize Minim and load the audio file
  minim = new Minim(this);
  player = minim.loadFile("Vaporwave_Allegro_Vivace_alt.mp3");
  player.loop();  // Play the audio file in a loop

  // Initialize Monome and step sequencer
  oscP5 = new OscP5(this, 12000);
  m = new Monome(this);
  step = new int[8][16];
  loop_end = 15;

  // Initialize step colors, avoiding white
  stepColors = new color[16];
  for (int i = 0; i < 16; i++) {
    stepColors[i] = color(random(255), random(255), random(255));
    while (brightness(stepColors[i]) > 200) { // Re-roll if the color is too close to white
      stepColors[i] = color(random(255), random(255), random(255));
    }
  }
}

void draw() {
  background(0);

  // Draw background layer
  pushMatrix();
  translate(width / 2, height / 2);
  rotateX(PI / 4);
  translate(-w / 2, -h / 2);

  for (int y = 0; y < rows - 1; y++) {
    for (int x = 0; x < cols - 1; x++) {
      beginShape();
      stroke(100, 100, 255 * brightness, 150);
      fill(100, 100, 255 * brightness, 50);
      vertex(x * scl, y * scl, z_bg[x][y] * 50);
      vertex((x + 1) * scl, y * scl, z_bg[x + 1][y] * 50);
      vertex((x + 1) * scl, (y + 1) * scl, z_bg[x + 1][y + 1] * 50);
      vertex(x * scl, (y + 1) * scl, z_bg[x][y + 1] * 50);
      endShape(CLOSE);
    }
  }

  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      z_bg[i][j] += deformSpeed * 0.5; // Slow down the deformation slightly to maintain complexity
      if (z_bg[i][j] > 1) z_bg[i][j] = -1; // Keep values within a more complex range
    }
  }
  popMatrix();

  // Draw foreground layer with color based on the current step
  pushMatrix();
  translate(width / 2, height / 2);
  rotateX(PI / 3);
  translate(-w / 2, -h / 2);

  for (int y = 0; y < rows - 1; y++) {
    for (int x = 0; x < cols - 1; x++) {
      beginShape();
      stroke(255 * brightness);
      fill(stepColors[play_position]);
      vertex(x * scl * scale, y * scl * scale, z[x][y] * 100 * scale);
      vertex((x + 1) * scl * scale, y * scl * scale, z[x + 1][y] * 100 * scale);
      vertex((x + 1) * scl * scale, (y + 1) * scl * scale, z[x + 1][y + 1] * 100 * scale);
      vertex(x * scl * scale, (y + 1) * scl * scale, z[x][y + 1] * 100 * scale);
      endShape(CLOSE);
    }
  }

  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      z[i][j] += deformSpeed * 0.5; // Slow down the deformation slightly to maintain complexity
      if (z[i][j] > 1) z[i][j] = -1; // Keep values within a more complex range
    }
  }
  popMatrix();

  // Draw additional 3D objects with the same step color
  pushMatrix();
  translate(width / 2, height / 8); // Position near top center

  for (int i = 0; i < objectPositions.length; i++) {
    pushMatrix();
    translate(objectPositions[i][0] * scale, objectPositions[i][1] * scale, z[i % cols][i % rows] * 100 * scale); // Spread objects horizontally and move
    drawComplex3DObject(stepColors[play_position]); // Use more complex shapes based on current step
    popMatrix();
  }
  popMatrix();

  // Monome Sequencer Logic
  if (timer == STEP_TIME) {
    if (cutting)
      play_position = next_position;
    else if (play_position == 15)
      play_position = 0;
    else if (play_position == loop_end)
      play_position = loop_start;
    else
      play_position++;

    // Trigger actions based on Monome input
    for (int y = 0; y < 6; y++) {
      if (step[y][play_position] == 1) {
        trigger(y, play_position);
      }
    }

    cutting = false;
    timer = 0;
    dirty = true;
  } else {
    timer++;
  }

  if (dirty) {
    int[][] led = new int[8][16];
    int highlight;

    // Display steps
    for (int x = 0; x < 16; x++) {
      if (x == play_position)
        highlight = 4;
      else
        highlight = 0;

      for (int y = 0; y < 6; y++)
        led[y][x] = step[y][x] * 11 + highlight;
    }

    // Draw trigger bar and on-states
    for (int x = 0; x < 16; x++) {
      led[6][x] = 4;
    }
    for (int y = 0; y < 6; y++) {
      if (step[y][play_position] == 1) {
        led[6][y] = 15;
      }
    }

    // Draw play position
    led[7][play_position] = 15;

    // Update grid
    m.refresh(led);
    dirty = false;
  }
}

void drawComplex3DObject(color c) {
  // More complex 3D object with additional shapes and rotations
  pushMatrix();
  rotateX(frameCount * 0.01);
  rotateY(frameCount * 0.01);
  
  // Drawing a complex shape (such as a tetrahedron with additional details)
  beginShape();
  stroke(255, 0, 0);
  fill(c, 150); // Use color from current step
  vertex(-30, -30, -30);
  vertex(30, -30, -30);
  vertex(30, 30, -30);
  vertex(-30, 30, -30);
  vertex(-30, -30, 30);
  vertex(30, -30, 30);
  vertex(30, 30, 30);
  vertex(-30, 30, 30);
  endShape(CLOSE);

  beginShape();
  stroke(0, 255, 0);
  fill(c, 150);
  vertex(-30, -30, -30);
  vertex(30, -30, -30);
  vertex(0, 0, 50);
  vertex(30, 30, -30);
  vertex(-30, 30, -30);
  endShape(CLOSE);

  popMatrix();
}

// Implement the trigger function to modify parameters based on the active step
public void trigger(int row, int col) {
  if (col < 4) {
    // Color control based on the first 4 columns
    stepColors[col] = color(random(255), random(255), random(255));
    // Avoid white colors
    while (brightness(stepColors[col]) > 200) {
      stepColors[col] = color(random(255), random(255), random(255));
    }
  } else if (col >= 4 && col < 8) {
    // Speed control based on the next 4 columns, with variation per row
    deformSpeed = map(col, 4, 7, 0.01, 0.1) * (row + 1);
  } else if (col >= 8 && col < 12) {
    // Brightness control based on the next 4 columns, with variation per row
    brightness = map(col, 8, 11, 0.5, 1.5) * (row + 1);
  } else if (col >= 12 && col < 16) {
    // Scale control based on the last 4 columns, with variation per row
    scale = map(col, 12, 15, 0.5, 2.0) * (row + 1);
  }
}

public void key(int x, int y, int s) {
  if (s == 1) {
    // Toggle step and set action based on column and row
    step[y][x] ^= 1;
    trigger(y, x);

    // Handle looping
    if (y == 7) {
      if (keys_held == 0) {
        loop_start = x;
      } else if (keys_held == 1) {
        loop_end = x;
        if (loop_end < loop_start) {
          int temp = loop_start;
          loop_start = loop_end;
          loop_end = temp;
        }
      }
      keys_held = (keys_held + 1) % 2;
    }

    dirty = true;
  }
}

public void stop() {
  // Stop the audio player when the sketch is stopped
  player.close();
  minim.stop();
  super.stop();
}
