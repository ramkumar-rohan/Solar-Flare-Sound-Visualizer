@import "utils.ck"

// class to generate random sound walk
public class SoundWalk
{
    // creates numWalks different random walks of length numSteps that end on the position corresponding to end, bounded by given ranges
    private static void populateRandomWalk(int numWalks, int numSteps, float xmin, float xmax, float ymin, float ymax, vec2 end[], vec2 out[][])
    {
        if (out.size() != numWalks || out[0].size() != numSteps)
        {
            <<<"size mismatch in populateRandomWalk()">>>;
            Machine.crash(); // lol why can i do this
            return;
        }

        0.005 => float step_scale_x; // how big the steps are relative to range
        0.05 => float step_scale_y; // how big the steps are relative to range
        0.01 => float epsilon; // tolerance for hitting edge

        for (0 => int j; j < numWalks; j++)
        {
            end[j] => vec2 target;
            target => out[j][numSteps - 1];
            for (numSteps - 2 => int i; i >= 0; i--)
            {
                // roll a gaussian to figure out next target
                target.x => float x_target;
                target.y => float y_target;
                randomGaussian(0, step_scale_x * (xmax - xmin)) => float x_update;
                randomGaussian(0, step_scale_y * (ymax - ymin)) => float y_update;
                if (x_target - xmin < epsilon) // bounce away from edge if on edge
                {
                    Math.fabs(x_update) => x_update;
                }
                else if (xmax - x_target < epsilon)
                {
                    -Math.fabs(x_update) => x_update;
                }
                if (y_target - ymin < epsilon) // bounce away from edge if on edge
                {
                    Math.fabs(y_update) => y_update;
                }
                else if (ymax - y_target < epsilon)
                {
                    -Math.fabs(y_update) => y_update;
                }

                x_update +=> x_target;
                y_update +=> y_target;
                // if hits edge of range then clip to range
                if (x_target < xmin)
                {
                    xmin => x_target;
                }
                else if (x_target > xmax)
                {
                    xmax => x_target;
                }

                if (y_target < ymin)
                {
                    ymin => y_target;
                }
                else if (y_target > ymax)
                {
                    ymax => y_target;
                }

                @(x_target, y_target) => target; // update target
                
                target => out[j][i];
            }
        }
    }

    // box-muller transform to convert uniform -> gaussian
    private static float randomGaussian(float mu, float sigma)
    {
        Math.randomf() => float u1;
        Math.randomf() => float u2;
        Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.pi * u2) => float z;
        return z * sigma + mu;
    }

    public static void runSound(Envelope envs[], Osc inputs[], float chord1[], float chord2[])
    {
        if (inputs.size() != chord1.size())
        {
            <<<"size mismatch in runSound()">>>;
            Machine.crash();
            return;
        }
        inputs.size() => int numInputs;

        5::second => dur startup_time; // how long to wait before starting
        90::second => dur walk_duration; // how long the walk will last
        10::second => dur chord1_duration; // how long the first chord will hold
        10::second => dur chord_transition; // how long to transition the chord
        15::second => dur end_duration; // how long the second chord will hold
        25::ms => dur update_time; // how often the walk will update

        0.75 => float max_gain; // max gain allowed
        
        (walk_duration / update_time) $ int => int numSteps;
        vec2 walk[numInputs][numSteps];
        
        vec2 end[numInputs];
        for (0 => int j; j < numInputs; j++)
        {
            @(Utils.logscale(chord1[j], 80, 2000), 1.) => end[j];
        }

        0. => float fmin;
        1. => float fmax;
        0.05 => float gmin; // stop popping
        1. => float gmax;

        0.3 => float smooth_freq;
        0.1 => float smooth_gain;


        populateRandomWalk(numInputs, numSteps, fmin, fmax, gmin, gmax, end, walk);
        int start_times[numInputs]; // when each voice should start coming in
        int curr_active[numInputs];
        for (0 => int j; j < numInputs; j++)
        {
            (numSteps / numInputs) * j => start_times[j]; // want integer division
            walk_duration / (2. * numInputs) => envs[j].duration; //float here
            0 => curr_active[j];
        }

        // initialize arrays
        float curr_freq[numInputs];
        float curr_gain[numInputs];
        for (0 => int j; j < numInputs; j++)
        {
            Utils.reverse_logscale(walk[j][0].x, 80., 2000.) => curr_freq[j];
            0 => curr_gain[j];
        }


        startup_time => now;

        0 => int numActive;
        for (0 => int i; i < numSteps; i++)
        {
            for (0 => int j; j < numInputs; j++)
            {
                if (i >= start_times[j] && curr_active[j] == 0)
                {
                    envs[j].keyOn(1);
                    numActive++;
                    1 => curr_active[j];
                }
                if (curr_active[j] == 1)
                {
                    Utils.reverse_logscale(walk[j][i].x, 80., 2000.) => float target_freq;
                    curr_freq[j] + smooth_freq * (target_freq - curr_freq[j]) => curr_freq[j];
                    curr_freq[j] => inputs[j].freq;

                    walk[j][i].y * max_gain / numActive => float target_gain;
                    curr_gain[j] + smooth_gain * (target_gain - curr_gain[j]) => curr_gain[j];
                    curr_gain[j] => inputs[j].gain;
                }
            }
            update_time => now;
        }
        
        // quickly reach chord now
        30 => int settle_steps;
        for (0 => int i; i < settle_steps; i++)
        {
            for (0 => int j; j < numInputs; j++)
            {
                chord1[j] => float chord_freq;
                curr_freq[j] + smooth_freq * (chord_freq - curr_freq[j]) => inputs[j].freq;

                
                max_gain / numInputs => float chord_gain;
                curr_gain[j] + smooth_gain * (chord_gain - curr_gain[j]) => inputs[j].gain;
            }
            update_time => now;
        }

        chord1_duration => now; // hold the chord

        (chord_transition / update_time) $ int => numSteps;
        for (0 => int i; i < numSteps; i++)
        {
            for (0 => int j; j < numInputs; j++)
            {
                chord1[j] + (i $ float) / (numSteps - 1) * (chord2[j] - chord1[j]) => inputs[j].freq;
            }
            update_time => now;
        }


        end_duration * 2 / 3=> now;
        for (0 => int j; j < numInputs; j++)
        {
            end_duration * 1 / 3 => envs[j].duration;
            envs[j].keyOff();
        }
        end_duration * 1 / 3 => now;

    }
}
