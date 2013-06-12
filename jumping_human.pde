//
//  jumping_human.pde
//
import ddf.minim.*;
import ddf.minim.analysis.*;
import controlP5.*;

float shutter_chance = 0.5;  // 0.0-1.0

long last_t = 0;
float bpm = 0.0;
float dulation = 0.0;
float human_y = 0.0; // 0.0-1.0
float timeout = 3.0; // (sec)
boolean is_take_picture = false;
int picture_frame_counter = 0;
float picture_frame_x;
float picture_frame_y;

Minim minim;
AudioPlayer se_jump;
AudioPlayer se_shutter;
AudioInput  mic_in;
FFT fft;
float [] fft_spec;
int fft_barchart_width;
int fft_idx = 0;
float fft_threshold = 100.0;

ControlP5 cp5;

void setup() {
  size(480, 640);

  PFont f = createFont("Impact", 32);
  textFont(f);

  minim = new Minim(this);

  // http://commons.nicovideo.jp/material/nc27131
  se_jump = minim.loadFile("nc27131.mp3");
  se_jump.setGain(-14.0);

  // http://commons.nicovideo.jp/material/nc2035
  se_shutter = minim.loadFile("nc2035.mp3");
  se_shutter.setGain(-14.0);

  mic_in = minim.getLineIn(Minim.MONO, 1024, 44100);
  mic_in.mute();
  fft = new FFT(mic_in.bufferSize(), mic_in.sampleRate());
  fft.window(FFT.HAMMING);
  fft.linAverages(30);
  fft_spec = new float[fft.avgSize()];
  fft_barchart_width = width / fft.avgSize();
  
  cp5 = new ControlP5(this);
  cp5.setColorForeground(0xff00aa00);
  cp5.setColorBackground(0xff006600);
  cp5.setColorLabel(0xff00dd00);
  cp5.setColorValue(0xff88ff88);
  cp5.setColorActive(0xff00bb00);
  cp5.addSlider("fft_idx").setSize(100,10).setPosition(10,60).setRange(0, fft.avgSize()-1);
  cp5.addSlider("fft_threshold").setSize(100,10).setPosition(10,80).setRange(0, fft_threshold);
}

void update() {
  if (bpm == 0.0) {
    clear_human_status();
    return;
  }

  float dt = (millis() - last_t) / 1000.0;
  if (dt > timeout) {
    clear_bpm_status();
    clear_human_status();
    return;
  }

  // calculate human position (0.0-1.0)
  float p = dt / dulation;
  if (p >= 1.0) p = 1.0;
  float th = PI * p;

  human_y = sin(th);
}

void draw() {
  process_mic_in();  
  update();

  background(0, 0, 0);

  // draw human body
  float x = width / 2;
  float y = (height * 0.7) * (1.0 - human_y) + height * 0.3;
  draw_human(x, y);

  // check shutter chance
  float p = (millis() - last_t) / 1000.0 / dulation;
  if (is_take_picture == false && human_y > 0.0 && p >= shutter_chance) {
    take_picture(x, y);
  }
  draw_picture_frame();

  noStroke();

  // debug info
  fill(0, 255, 0);
  text(String.format("bpm=%.2f, dulation=%.2f(s)", bpm, dulation), 30, 30);

  draw_mic_in();
}

void stop() {
  se_jump.close();
  se_shutter.close();
  mic_in.close();
  minim.stop();
  super.stop();
}

int guard_counter = 0;
void process_mic_in() {
  fft.forward(mic_in.mix);
  for (int i = 0; i < fft.avgSize(); ++i) {
    fft_spec[i] = fft.getAvg(i);
  }

  int idx = mouseX / fft_barchart_width;
  if (idx <  fft.avgSize()) {
    float freq = fft.indexToFreq(idx);
    println(String.format("idx=%d, freq=%.2f, avg=%.2f", idx, freq, fft.getAvg(idx)));
  }
  
  if (fft.getAvg(fft_idx) > fft_threshold && guard_counter ==0) {
    guard_counter = 20;
    fire_jump();
  }
  
  if (guard_counter > 0) guard_counter --;
}

void keyPressed() {
  fire_jump();
}

void mousePressed() {
  fire_jump();
}
 
void fire_jump() {
  long t = millis();
  float dt = (t - last_t) / 1000.0;

  if (dt < timeout) {
    calc_initial_human_status(dt);
    se_jump.play(0);
  }
  else {
    clear_bpm_status();
  }
  last_t = t;
}

void calc_initial_human_status(float dt) {
  dulation = dt;
  bpm = 60.0 / dt;

  clear_human_status();
}

void clear_human_status() {
  human_y = 0.0;
  is_take_picture = false;
}
void clear_bpm_status() {
  bpm = 0.0;
  dulation = 0.0;
}

void draw_human(float  x, float y) {
  noStroke();
  fill(0, 255, 0);

  ellipseMode(CENTER);
  ellipse(x, y - 100, 50, 50);

  stroke(0, 255, 0);
  strokeWeight(2);
  line(x, y - 100, x, y - 40);
  line(x - 30, y -  60, x + 30, y - 60);
  line(x, y -  40, x - 20, y     );
  line(x, y -  40, x + 20, y     );
}

void take_picture(float x, float y) {
  se_shutter.play(0);
  is_take_picture = true;
  picture_frame_counter = 0;

  picture_frame_x = x;
  picture_frame_y = y;
}

void draw_picture_frame() {
  if (is_take_picture == false) return;
  if (picture_frame_counter >= 6) return;

  stroke(255, 255, 255);
  strokeWeight(20);
  noFill();

  rect(picture_frame_x - 100, picture_frame_y - 150, 200, 200);  

  picture_frame_counter ++;
}

void draw_mic_in() {
  fill(0, 128, 0);
  for (int i = 0; i < fft_spec.length; i++) {
    rect(i * fft_barchart_width, height, fft_barchart_width, -Math.round(fft_spec[i]));
  }
}

