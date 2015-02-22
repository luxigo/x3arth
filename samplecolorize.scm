(define (sample-colorize samplefile
                         imagefile
                         outfile)
  (let* (
        (run_mode RUN-NONINTERACTIVE)
        (image (gimp-file-load run_mode imagefile imagefile))
        (sample (gimp-file-load run_mode samplefile samplefile))
        (sample_drawable (gimp-image-get-active-drawable (car sample)))
        (dst_drawable (gimp-image-get-active-drawable (car image)))
        (hold_inten 1)
        (orig_inten 1)
        (rnd_subcolors 0)
        (guess_missing 0)
        (in_low 0)
        (in_high 255)
        (gamma 1.0)
        (out_low 0)
        (out_high 255)
        )
        (gimp-image-convert-rgb (car image))
        (plug-in-sample-colorize run_mode (car image) (car dst_drawable) (car sample_drawable) hold_inten orig_inten rnd_subcolors guess_missing in_low in_high gamma out_low out_high)
        (gimp-levels-stretch (car dst_drawable))
        (gimp-file-save run_mode (car image) (car dst_drawable) outfile outfile)
        (gimp-quit 0)
   )
)


