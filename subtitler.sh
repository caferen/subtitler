#!/bin/bash

PATH="/opt/cuda/bin:$PWD:$PATH"

sudo pacman -S --needed make git ffmpeg cuda nodejs npm

ffmpeg -i "$1" -ar 16000 -ac 1 -c:a pcm_s16le output.wav

if [[ ! -f ./whisper.cpp/main ]]; then
    git clone https://github.com/ggerganov/whisper.cpp
    (
        cd whisper.cpp
        bash ./models/download-ggml-model.sh large

        if ! which nvcc; then
            make
        else
            WHISPER_CUBLAS=1 make -j
        fi
    )
fi

(
    cd whisper.cpp
    ./main -m models/ggml-large.bin -l auto -osrt true -f ../output.wav
)

if [[ ! -f ./translator/cli/translator.mjs ]]; then
    git clone https://github.com/Cerlancism/chatgpt-subtitle-translator translator
    (
        cd translator
        npm install
        chmod +x cli/translator.mjs
    )
fi

(
    cd translator
    cli/translator.mjs --stream --temperature 0 --file ../output.wav.srt --from en -to tr
)
