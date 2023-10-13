#!/bin/bash

sudo pacman -S --needed make git ffmpeg cuda python-pipx
pipx install translatesubs

filename="$(basename "$1" | sed 's/\(.*\)\..*/\1/')"
dir="$filename"
wav_file="${filename}.wav"

mkdir "$dir"

ffmpeg -i "$1" -ar 16000 -ac 1 -c:a pcm_s16le "${dir}/${wav_file}"

if [[ ! -f ./whisper.cpp/main ]]; then
    git clone https://github.com/ggerganov/whisper.cpp
    (
        cd whisper.cpp
        bash ./models/download-ggml-model.sh large

        if [[ ! -f /opt/cuda/bin/nvcc ]]; then
            make
        else
            WHISPER_CUBLAS=1 make -j
        fi
    )
fi

(
    cd whisper.cpp
    ./main -m models/ggml-large.bin -l auto -osrt true -f ../"${dir}/${wav_file}"
)

(
    cd "$dir"
    translatesubs "${wav_file}.srt" "${filename}_tr.srt" --to_lang tr --separator " |||  "
    ffmpeg -i ../"$1" -vf subtitles="${filename}_tr.srt" "${filename}_tr_subs".mp4
)
