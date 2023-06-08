## setting change
1. structured-ocr/engine/resource/config.ini
timeout = 120 ⇒ 1200 * Because it takes time locally. No need to change if unnecessary.

2. structured-ocr/engine/image_detection/infordio_ocr/crnn_pl_config.cfg
Since the path of the model is described by the absolute path, change to the path suitable for your environment

3. Model placement
structured-ocr/engine/image_detection/models/
Place the following model in the above.
crnn
pl

4. Change environment variables
export PYTHONPATH=/Path of each environment/structured-ocr/engine:/Path of each environment/structured-ocr/engine/image_detection
* Because our project depends on those package
Compile
When changes are added to the target file (*. Pyx), compiling is necessary.
1. Move folder
   
    `cd structured_ocr/engine/`
2. Compile
   
    `python setup.py build_ext --inplace`

    * 1 If a compile error occurs here, correct * .pyx according to error message
    
    * 2 There is description of target file to be compiled in setup.py. Refer to the Cython document for descriptions and instructions.

3. Confirm that * .so file is created in the directory with * .pyx

* When you commit the target file after compiling, upload only the *. Pyx file. (* .so files, * .c and build directories are unnecessary)

## Start-up
`cd structured-ocr/engine/table-extraction/`
`python extract_region.py -p test/data/01.jpg -g 1'
-p: Path to analysis image
-g: Debug execution 0: Normal 1: Debug
*Image debug will be saved at structured-ocr/engine/table-extraction/debug

4. Note:
The main method for extract_region.py is extract_box_line_region()
This method extract all table frames, table real-lines, table virtual-lines as rectange list
5. The output will be:
    table_frames: list of table bounding box
    table_real_lines: list of table real-lines as rectangle
    table_virtual_lines: list of table virtual-lines as rectangle