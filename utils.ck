// all my utils functions yummy
public class Utils
{
    1024 => static int WINDOW_SIZE;

    // fft window
    Windowing.hann(WINDOW_SIZE) @=> static float window[];

    // sample variables
    static float samples[0];

    // map input samples to waveform 
    public static void map2waveform( float in[], float out[] )
    {
        if( in.size() != out.size() )
        {
            <<< "size mismatch in map2waveform()", "" >>>;
            return;
        }
        
        for (int i; i < in.size(); i++)
        {
            // map y, using window function to taper the ends
            Math.max(Math.min(in[i], 0.1), -0.1) * 1 * window[i] => out[i]; // clip it to not be too big
        }
    } 

    // spectrum map
    public static void map2spectrum( complex in[], float out[] )
    {
        if( in.size() != out.size() )
        {
            <<< "size mismatch in map2spectrum()", "" >>>;
            return;
        }
        
        for (int i; i < in.size(); i++)
        {
            // map frequency bin magnitide in Y
            25 * Math.sqrt( (in[i]$polar).mag ) => out[i];
        }
    }

    // copied from https://github.com/ArashPartow/bitmap/blob/master/bitmap_image.hpp#L2851
    // approximates light wavelength to rgb vec3
    public static vec3 convert_wave_length_nm_to_rgb(float wave_length_nm)
    {
       // Credits: Dan Bruton http://www.physics.sfasu.edu/astro/color.html
       0. => float red;
       0. => float green;
       0. => float blue;

       if ((380.0 <= wave_length_nm) && (wave_length_nm <= 439.0))
       {
          -(wave_length_nm - 440.0) / (440.0 - 380.0) => red;
          1.0 => blue;
       }
       else if ((440.0 <= wave_length_nm) && (wave_length_nm <= 489.0))
       {
          (wave_length_nm - 440.0) / (490.0 - 440.0) => green;
          1.0 => blue;
       }
       else if ((490.0 <= wave_length_nm) && (wave_length_nm <= 509.0))
       {
          1.0 => green;
          -(wave_length_nm - 510.0) / (510.0 - 490.0) => blue;
       }
       else if ((510.0 <= wave_length_nm) && (wave_length_nm <= 579.0))
       {
          (wave_length_nm - 510.0) / (580.0 - 510.0) => red;
          1.0 => green;
       }
       else if ((580.0 <= wave_length_nm) && (wave_length_nm <= 644.0))
       {
          1.0 => red;
          -(wave_length_nm - 645.0) / (645.0 - 580.0) => green;
       }
       else if ((645.0 <= wave_length_nm) && (wave_length_nm <= 780.0))
       {
          1.0 => red;
       }

       0. => float factor;

       if ((380.0 <= wave_length_nm) && (wave_length_nm <= 419.0))
          0.3 + 0.7 * (wave_length_nm - 380.0) / (420.0 - 380.0) => factor;
       else if ((420.0 <= wave_length_nm) && (wave_length_nm <= 700.0))
          1.0 => factor;
       else if ((701.0 <= wave_length_nm) && (wave_length_nm <= 780.0))
          0.3 + 0.7 * (780.0 - wave_length_nm) / (780.0 - 700.0) => factor;

       vec3 result;

       0.8 => float gamma;


       ((red   == 0.0) ? red   : Math.pow(red   * factor, gamma)) => result.x;
       ((green == 0.0) ? green : Math.pow(green * factor, gamma)) => result.y;
       ((blue  == 0.0) ? blue  : Math.pow(blue  * factor, gamma)) => result.z;


       return result;
    }    

}
