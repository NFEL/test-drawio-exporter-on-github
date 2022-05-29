# Steps To run locally
- Install PDM
  -  ```curl -sSL https://raw.githubusercontent.com/pdm-project/pdm/main/install-pdm.py | python3 -```
- Export PDM to your shell
  - BASH
    - ```export PATH=$HOME/.local/bin:$PATH```
    - ```pdm --pep582 >> ~/.bash_profile```
    - ```pdm completion bash > /etc/bash_completion.d/pdm.bash-completion```
  - Fish
    -  ```set PATH "$HOME/.local/bin:$PATH"```
    -  ```set -x PYTHONPATH '/home/nfel/.local/share/pdm/venv/lib/python3.8/site-packages/pdm/pep582' $PYTHONPATH ```
    -  pdm completion fish > ~/.config/fish/completions/pdm.fish```
       -  if faced directory not found error:
          - ```mkdir ~/.config/fish/completions/```
- Install Dependencies 
  - pdm install -G doc
- Install Drawio in your machine
  - [Visit Here](https://github.com/jgraph/drawio-desktop/releases/tag/v18.1.3)
    - [Deb](https://github.com/jgraph/drawio-desktop/releases/download/v18.1.3/drawio-amd64-18.1.3.deb)
    - [RPM](https://github.com/jgraph/drawio-desktop/releases/download/v18.1.3/drawio-x86_64-18.1.3.rpm)
  - ```sudo apt install -i <drawio-release-name.deb>```
- Run Live server 
  - pdm run mkdocs serve --livereload

# Steps to Deploy 
Nginx serves the files ```pdm run mkdocs build``` generated!

## Extra Tools
- diagrams:
  - mermaid
    - https://mermaid.live/
    - https://mermaid-js.github.io/mermaid/#/flowchart
- 