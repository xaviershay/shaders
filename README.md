    sudo apt-get install libgl1-mesa-dev xorg-dev
    go install github.com/polyfloyd/shady/cmd/shady@latest
    shady -w -i test.glsl
