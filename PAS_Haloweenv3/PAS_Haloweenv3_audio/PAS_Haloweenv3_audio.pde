import org.monome.Monome;
import oscP5.*;
import netP5.*;
import ddf.minim.*;
import java.util.ArrayList;

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

ArrayList<VisualElement> elements;

// Variables to control parameters
float lineThickness = 2.0;
float lineSpeed = 1.0;
float circleSize = 100.0;
float lineLength = 100.0;

// Min and max values for parameters
float minLineThickness = 1.0;
float maxLineThickness = 10.0;

float minLineSpeed = 1.0;
float maxLineSpeed = 10.0;

float minCircleSize = 20.0;
float maxCircleSize = 200.0;

float minLineLength = 50.0;
float maxLineLength = 500.0;

// Audio playback variables
Minim minim;
AudioPlayer player;

public void setup() {
  size(2560, 1400);
  background(0);
  frameRate(60);
  stroke(255, 204);

  // Initialize audio playback
  minim = new Minim(this);
  player = minim.loadFile("Defribulater_new_alt116.wav"); // Replace with your audio file name
  player.loop();

  m = new Monome(this);

  dirty = true;
  step = new int[6][16];
  loop_end = 15;

  elements = new ArrayList<VisualElement>();
}

public void draw() {
  // Semi-transparent black background for motion trails
  fill(0, 20);
  rect(0, 0, width, height);

  // Avant-garde effect: random flickering lines with interactive parameters
  stroke(255, random(50, 100));
  strokeWeight(lineThickness);

  // Determine the number of lines to draw based on lineSpeed
  int numLines = (int) lineSpeed;
  if (random(1) < (lineSpeed - numLines)) {
    numLines += 1;
  }

  for (int i = 0; i < numLines; i++) {
    float x1 = random(width);
    float y1 = random(height);
    float x2 = x1 + random(-lineLength, lineLength);
    float y2 = y1 + random(-lineLength, lineLength);
    line(x1, y1, x2, y2);
  }

  // Update and display all visual elements
  for (int i = elements.size() - 1; i >= 0; i--) {
    VisualElement e = elements.get(i);
    e.update();
    e.display();
    if (e.isDead()) {
      elements.remove(i);
    }
  }

  // Grain effect to mimic film texture
  loadPixels();
  for (int i = 0; i < pixels.length; i++) {
    int c = pixels[i];
    float r = red(c) + random(-10, 10);
    pixels[i] = color(constrain(r, 0, 255));
  }
  updatePixels();

  // Monome step sequencer logic
  if (timer == STEP_TIME) {
    if (cutting)
      play_position = next_position;
    else if (play_position == 15)
      play_position = 0;
    else if (play_position == loop_end)
      play_position = loop_start;
    else
      play_position++;

    // Trigger visuals for active steps
    for (int y = 0; y < 6; y++)
      if (step[y][play_position] == 1)
        trigger(y, play_position);

    cutting = false;
    timer = 0;
    dirty = true;
  } else
    timer++;

  if (dirty) {
    int[][] led = new int[8][16];
    int highlight;

    // Display steps
    for (int x = 0; x < 16; x++) {
      // Highlight the play position
      if (x == play_position)
        highlight = 4;
      else
        highlight = 0;

      for (int y = 0; y < 6; y++)
        led[y][x] = step[y][x] * 11 + highlight;
    }

    // Draw trigger bar and on-states
    for (int x = 0; x < 16; x++)
      led[6][x] = 4;
    for (int y = 0; y < 6; y++)
      if (step[y][play_position] == 1)
        led[6][y] = 15;

    // Draw play position
    led[7][play_position] = 15;

    // Update grid
    m.refresh(led);
    dirty = false;
  }
}

public void key(int x, int y, int s) {
  // Toggle steps
  if (s == 1 && y < 6) {
    step[y][x] ^= 1;
    dirty = true;
  }
  // Cut and loop
  else if (y == 7) {
    // Track number of keys held
    keys_held = keys_held + (s * 2) - 1;

    // Cut
    if (s == 1 && keys_held == 1) {
      cutting = true;
      next_position = x;
      key_last = x;
    }
    // Set loop points
    else if (s == 1 && keys_held == 2) {
      loop_start = key_last;
      loop_end = x;
    }
  }
}

public void trigger(int row, int column) {
  // Adjust parameters based on the row and column
  switch (row) {
    case 0: // Control lineThickness
      lineThickness = map(column, 0, 15, minLineThickness, maxLineThickness);
      break;
    case 1: // Control lineSpeed
      lineSpeed = map(column, 0, 15, minLineSpeed, maxLineSpeed);
      break;
    case 2: // Control circleSize
      circleSize = map(column, 0, 15, minCircleSize, maxCircleSize);
      break;
    case 3: // Control lineLength
      lineLength = map(column, 0, 15, minLineLength, maxLineLength);
      break;
    default:
      // Other rows can maintain previous behaviors or be assigned new ones
      break;
  }

  // Create a new visual element using the current circleSize
  float posX = width / 2;
  float posY = height / 2;
  elements.add(new VisualElement(posX, posY, circleSize));
}

// Class representing visual elements
class VisualElement {
  float x, y;
  float size;
  float alpha;
  float noiseOffsetX, noiseOffsetY;
  float angle;
  color col;

  VisualElement(float x, float y, float size) {
    this.x = x;
    this.y = y;
    this.size = size;
    alpha = 255;
    noiseOffsetX = random(1000);
    noiseOffsetY = random(1000);
    angle = 0;
    col = color(255, alpha);
  }

  void update() {
    // Movement influenced by Perlin noise for organic motion
    x += map(noise(noiseOffsetX), 0, 1, -1, 1);
    y += map(noise(noiseOffsetY), 0, 1, -1, 1);
    noiseOffsetX += 0.01;
    noiseOffsetY += 0.01;

    // Gradually fade out faster
    alpha -= 5; // Increase the decrement for faster fade
    if (alpha < 0) {
      alpha = 0;
    }

    // Update color alpha
    col = color(red(col), green(col), blue(col), alpha);
  }

  void display() {
    pushMatrix();
    translate(x, y);
    noFill();
    stroke(col);
    strokeWeight(2);
    ellipse(0, 0, size, size);
    popMatrix();
  }

  boolean isDead() {
    return alpha == 0;
  }
}

// Stop audio when the sketch is closed
public void stop() {
  player.close();
  minim.stop();
  super.stop();
}
