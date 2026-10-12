// class to generate random sound walk
public class SoundWalk
{
    // creates numWalks different random walks of length numSteps that end on the position corresponding to end, bounded by given ranges
    private static populateRandomWalk(int numWalks, int numSteps, float xmin, float xmax, float ymin, float ymax, vec2 end[], vec2 out[][])
    {
        if (out.size() != numWalks || out[0].size() != numSteps)
        {
            <<<"size mismatch in populateRandomWalk()">>>;
            Machine.crash(); // lol why can i do this
            return;
        }

        0.1 => float step_scale; // how big the steps are relative to range
        0.01 => float epsilon; // tolerance for hitting edge
        0.8 => float vel; // smoothing out walk a little

        for (0 => int j; j < numWalks; j++)
        {
            end[j] => vec2 curr;
            curr => vec2 target;
            for (numSteps - 1 => int i; i >= 0; i--)
            {
                // roll a gaussian to figure out next target
                target.x => float x_target;
                target.y => float y_target;
                randomGaussian(0, step_scale * (xmax - xmin)) => float x_update;
                randomGaussian(0, step_scale * (ymax - ymin)) => float y_update;
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

                if (x_target < ymin)
                {
                    ymin => y_target;
                }
                else if (y_target > ymax)
                {
                    ymax => y_target;
                }

                @(x_target, y_target) => target; // update target
                
                curr + vel * (target - curr) => curr; //update current position

                curr => out[j][i];
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

    public static void runSound(Osc inputs[])
    {
        3 => int numInputs;
        if (inputs.size() != numInputs)
        {
            <<<"size mismatch in runSound()">>>;
            Machine.crash();
            return;
        }

        5::second => dur walk_duration; // how long the walk will last
        10::second => dur end_duration; // how long the final chord will hold
        50::ms => dur update_time; // how often the walk will update
        
        (walk_duration / update_time) $ int => int numSteps;
        vec2 walk[numInputs][numSteps];
        [@(261.63, 0.3), @(329.63, 0.3), @(392.00, 0.3)] @=> vec2 end[]; // TODO make it logarithmic? so it isn't too weird

        200 => float fmin;
        400 => float fmax;
        0.2 => float gmin;
        0.7 => float gmax;

        populateRandomWalk(numInputs, numSteps, fmin, fmax, gmin, gmax, end, walk);

        for (0 => int i; i < numSteps; i++)
        {
            for (0 => int j; j < numInputs; j++)
            {
                walk[j][i].x => inputs[j].freq;
                walk[j][i].y => inputs[j].gain;
            }
            update_time => now;
        }
        end_duration => now;

        for (0 => int j; j < numInputs; j++)
        {
            0 => inputs[j].gain;
        }
    }
}
