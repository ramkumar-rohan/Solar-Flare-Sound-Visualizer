@import "utils.ck" // make my life easier by putting the big functions in another file
GWindow.fullscreen(); // make it fullscreen
GOrbitCamera orbit_cam --> GG.scene(); // allow camera control of image
GG.scene().camera(orbit_cam);



//copied from soundbulb, make it bloom
GG.bloom(true);
GG.bloomPass().intensity(2);
GG.bloomPass().radius(0.5);
GG.bloomPass().levels(9);

//make a geometry for the sun
SphereGeometry sun_geo;
sun_geo.build(
  1.0,        // radius
  64,         // # segments along width of sphere (default 32)
  64,          // # segments along vertical arc of sphere (default 16)
  0,          // phiStart
  Math.PI * 2, // phiLength   (phi in spherical coordinates)
  0,          // thetaStart
  Math.PI     // thetaLength (theta in spherical coordinates)
);

// load shader from file
ShaderDesc shader_desc;
me.dir() + "shader.wgsl" => shader_desc.vertexPath; // load vertex shader
me.dir() + "shader.wgsl" => shader_desc.fragmentPath; // load fragment shader
Shader sun_shader(shader_desc);
Material sun_mat(sun_shader);

// pass initial colors in the shader, will be updated
sun_mat.uniformFloat3(0, 5 * Color.RED);
sun_mat.uniformFloat3(1, 1 * Color.ORANGE); // this one doesn't change though, I haven't come up with a cool way to update it yet
GMesh sun(sun_geo, sun_mat);

// load sun into scene
sun --> GG.scene();


// set initial color variable, this will be what continuously updates the colors
Color.RED => vec3 curr_col;

// fft window size
1024 => int WINDOW_SIZE;

UGen input;
int input_source;
0 => input_source; // could make this controllable from keyboard input later

if (input_source == 0)
{
    adc => input;
}
else if (input_source == 1)
{
    SinOsc sin => input; 0.1 => sin.gain;
}
// maybe third option can play a custom thing

//pass input into accumulator
input => Flip accum => blackhole;

//make it equal to fft size for math reasons
WINDOW_SIZE => accum.size;

// pass input into fft
input => PoleZero dcbloke => FFT fft => blackhole;
 
// set DC blocker
.95 => dcbloke.blockZero;
Windowing.hann(WINDOW_SIZE) => fft.window;
WINDOW_SIZE*2 => fft.size;

// accumulator samples
float samples[0];
// FFT response
complex response[0];
// calculated amplitudes
float amplitudes[WINDOW_SIZE];

// calculated spectrum response
float spectrum[WINDOW_SIZE];

// alll the audio processing
fun void doAudio()
{
    while( true)
    {
        // upchuck to process accum
        accum.upchuck();
        // get the last window size samples (waveform)
        accum.output( samples );
        // upchuck to take FFT, get magnitude response
        fft.upchuck();
        // get spectrum (as complex values)
        fft.spectrum( response );
        // jump by samples
        WINDOW_SIZE::samp/2 => now;
    }
}

// cross product of two vectors because i dont think this exists in chuck already
fun vec3 crossProduct( vec3 vec1, vec3 vec2) 
{
    vec3 vec;
    vec1.y * vec2.z - vec1.z * vec2.y => vec.x;
    vec1.z * vec2.x - vec1.x * vec2.z => vec.y;
    vec1.x * vec2.y - vec1.y * vec2.x => vec.z;
    return vec;
     
}

// dot product of two vectors
fun float dot(vec3 vec1, vec3 vec2)
{
    return vec1.x * vec2.x + vec1.y * vec2.y + vec1.z * vec2.z;
}

// norm of a vector
fun float norm(vec3 vec)
{
    return Math.sqrt(dot(vec, vec));
}

// quadratic interpolation as i goes from 0 to NUM_POINTS, maximum around NUM_POINTS / 2 and zero at i=0 and i=NUM_POINTS-1
fun float quadratic_interpolation(int i, int NUM_POINTS)
{
    return -4 * i $ float / (NUM_POINTS-1) *(i $ float / (NUM_POINTS-1) - 1); 
}

// draw a single flare
fun void genFlare()
{
    //Using Marsaglia's polar method for finding a random unit vector, this is just some math magic
    float u1, u2, s;
    do
    {
        Math.random2f(-1,1) => u1;
        Math.random2f(-1,1) => u2;
        u1 * u1 + u2 * u2 => s;
    } while (s >= 1); // do while my beloved

    @(2*u1*Math.sqrt(1-s), 2*u2*Math.sqrt(1-s), 1-2*s) => vec3 normal;

    //picking a vector on the plane by finding the vector perpendicular to both normal and (1,0,0)
    crossProduct(@(1,0,0), normal) => vec3 v1;
    if (norm(v1) < 0.1) // if normal is already close to (1,0,0) then we might get floating point problems, so use (0,1,0) instead
    {
        crossProduct(@(0,1,0), normal) => v1;
    }
    v1 / norm(v1) => v1; // normalize to get a unit vector in the plane

    //vector orthogonal to v1 on the plane
    crossProduct(v1, normal) => vec3 v2;
    
    // pick a random phase so that it starts randomly
    Math.random2f(0, 2*Math.pi) => float phase;

    // number of points equal to window size so each sample can affect the points
    WINDOW_SIZE => int NUM_POINTS;
    // particle velocity
    0.1 => float vel;

    //draw all the points
    GPoints points --> GG.scene();
   
    // allow the flares to be transparent
    1 => points.material().transparent;
    // make it so that a color of zero is transparent, idk how this works
    2 => points.material().blend;

    0.1 => points.size;

    vec3 base_point_colors[NUM_POINTS]; // these are the colors as soon as it spawns in
    vec3 real_point_colors[NUM_POINTS]; // these are the real colors as it evolves and fades over time
    curr_col => vec3 color_remember; // this is the current color of the sun, remembers this color for the lifespan of the flare, even if the sun color changes
    for (0 => int i; i < NUM_POINTS; i++)
    {
        color_remember * 5 * quadratic_interpolation(i, NUM_POINTS) => base_point_colors[i]; // fade away toward edges of arc quadratically
    }
    vec3 base_point_positions[NUM_POINTS]; // position of points without the sound response
    vec3 real_point_positions[NUM_POINTS]; // real position with the sound response

    float t; // interpolate along the arc
    for (0 => int i; i < NUM_POINTS; i++)
    {
        phase + Math.pi / NUM_POINTS * i => t; // only pi and not 2pi because half arc
        Math.cos(t) * v1 + Math.sin(t) * v2 => base_point_positions[i]; // go around the circle
    }
    1 => float color_decay; // rate to decay color
    1 => float response_decay; // rate to decay audio response
    repeat(90) // do this 90 times for a total lifetime of 4.5 seconds, after which it should be faded almost completely
    {
        vec3 dir; // direction for each particle to blow up
        //exponentially decaying opacity and response to sound  
        0.90 *=> color_decay; // exponential decay
        0.95 *=> response_decay; // exponential decay
        for (0 => int i; i < NUM_POINTS; i++)
        {
            base_point_positions[i] / norm(base_point_positions[i]) => dir; // set direction to be normalized position
            base_point_positions[i] + dir * vel * quadratic_interpolation(i,NUM_POINTS) => base_point_positions[i]; // blow up proportional to velocity and quadratic interpolation
            base_point_positions[i] + 20 * response_decay * amplitudes[i] * dir => real_point_positions[i]; // response to amplitude
            color_decay * base_point_colors[i] => real_point_colors[i]; // color decay
        }
         
        real_point_positions => points.positions;
        real_point_colors => points.colors;
        50::ms => now;
    }
    points --< GG.scene(); // ungruck the points from the sceen
}

// make all the flares
fun void flares()
{
    while (true)
    {
        spork ~ genFlare(); // flares in parallel
        1::second => now; // one flare every second
    }
}


// converts a frequency bin to real frequency in hertz. when k = windowsize, the frequency corresponds to half the sample rate because nyquist
// TODO: maybe add some kind of parabolic interpolation with the frequencies near the max to get better resolution, right now the frequency resolution is very limited
fun float binToFreq(int k)
{
    return k * (second / samp) / (2 * WINDOW_SIZE);
}

// update the sun colors
fun void updateColors()
{
    // find the bin with greatest frequency
    0 => int max_index;
    for (0 => int i; i < WINDOW_SIZE; i++)
    {
        if (spectrum[i] > spectrum[max_index])
        {
            i => max_index;
        }
    }
   
    vec3 target_col;
    binToFreq(max_index) => float freq;
    if (spectrum[max_index] < 1) // probably just noise from what i've tested
    {
        Utils.convert_wave_length_nm_to_rgb(750) => target_col; // this is red
    }
    else
    {
        // log scale between 80 and 2000 hz, seems pretty good from testing
        Math.log(Math.max(freq, 80.0) - 80.0) / Math.log(2000.0 - 80.0) => float t;
        1 - (Std.clampf(t, 0.0, 1.0)) => t; // bigger frequency means smaller wavelength so i reverse it
        
        // 400-750 is approximately visible light spectrum
        400 + t * (750 - 400) => float wavelength;
        
        // funny function i found online and adapted to chuck
        Utils.convert_wave_length_nm_to_rgb(wavelength) => target_col;
    }

    curr_col + 0.025 * (target_col - curr_col) => curr_col; //smooth out frequency changes by doing it like this


    sun_mat.uniformFloat3(0, 5 * curr_col); // set color to this color

}

// audio and flare code in parallel
spork ~ doAudio();
spork ~ flares();

// main graphics loop
while (true)
{
    GG.nextFrame() => now;
    Utils.map2waveform(samples, amplitudes ); // process amplitudes
    Utils.map2spectrum( response, spectrum ); // process spectrum
    updateColors(); // update sun colors
}
