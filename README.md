# Tone Mapping Toolbox

## Introduction

This repository is an integrated toolbox and platform for commonly used tone mapping algorithms in engineering applications. The platform provides a unified interface for generating global tone mapping curves, color protection logic, standardized input/output, and includes several standard tone mapping operators. All operators follow a standardized function interface, making it easy to switch between different algorithms and extend the toolbox.

## Usage

1. **Clone the repository:**
    ```bash
    git clone https://github.com/yourname/tone_mapping_toolbox.git
    cd tone_mapping_toolbox
    ```

2. **Select the tone mapping method:**
    - Open `main_tone.m` in MATLAB.
    - Modify the `method` variable to the desired tone mapping method (e.g., `'llf'`, `'glb'`, `'dgain'`, `'gf'`, `'no_tone'`).

3. **Run the main script:**
    - The script will process several input images included in the `data` folder and save the results in the `results` directory.

## Citation and Copyright

1. This toolbox references academic papers and code, including:
    - [Fast Local Laplacian Filters: Theory and Applications (SIGGRAPH 2011)](https://people.csail.mit.edu/sparis/publi/2011/siggraph/)
    - If you believe your rights are infringed, please contact the author at: hgr215@163.com

2. **License Statement**
    - This repository is for research and educational purposes only.
    - Commercial use is NOT permitted.
    - Please respect the original authors and cite relevant works where appropriate.