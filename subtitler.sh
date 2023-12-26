#!/bin/bash

if [ ! $# -eq 2 ]
then
    echo "Input filename and abbreviated target language in that order."
    exit 0
fi

sudo pacman -S --needed make git ffmpeg cuda python-pipx
pipx install translatesubs

filepath=$(readlink -f "$1")
filename="$(basename "$1" | sed 's/\(.*\)\..*/\1/')"
wav_file="${filename}.wav"
lang="$2"
subtitler_dir="${HOME}/.cache/subtitler"
output_dir="${PWD}/${filename}"
whisper_dir="${subtitler_dir}/whisper"
whisper="${whisper_dir}/main"
model="${whisper_dir}/models/ggml-large.bin"

mkdir -p "$subtitler_dir"
mkdir -p "$output_dir"

ffmpeg -i "$filepath" -ar 16000 -ac 1 -c:a pcm_s16le "${output_dir}/${wav_file}" -y

if [[ ! -f "$whisper" ]]; then
    git clone https://github.com/ggerganov/whisper.cpp "$whisper_dir"
fi

(
    cd "$whisper_dir"
    bash ./models/download-ggml-model.sh large

    if [[ ! -f /opt/cuda/bin/nvcc ]]; then
        make
    else
        WHISPER_CUBLAS=1 make -j
    fi
)

"$whisper" -m  "$model" -l auto -osrt true -f "${output_dir}/${wav_file}"

echo "Translating subtitles. This will take a while if the media file is large."
translatesubs "${output_dir}/${wav_file}.srt" "${output_dir}/${filename}_${lang}.srt" --to_lang "$lang"

# try another separator if the defaults fail
if [[ ! -f "${output_dir}/${filename}_${lang}.srt" ]]; then
    translatesubs "${output_dir}/${wav_file}.srt" "${output_dir}/${filename}_${lang}.srt" --to_lang "$lang" --separator " |||  "
fi

if ffmpeg -version | grep -F -- --enable-libass &> /dev/null; then
    echo "Embedding subtitles back into the original media..."

    ffmpeg -i "$filepath" -vf subtitles="${output_dir}/${filename}_${lang}.srt" "${output_dir}/${filename}_${lang}_hardsubs".mp4 -y
    ffmpeg -i "$filepath" -i "${output_dir}/${filename}_${lang}.srt" \
        -i "${output_dir}/${wav_file}.srt" -map 0 -map 1 -map 2 -c copy -c:s mov_text \
        -metadata:s:s:0 language="$lang" -metadata:s:s:0 language=original \
        "${output_dir}/${filename}_${lang}_softsubs".mp4 -y
else
    echo "libass is not enabled for FFMPEG. Cannot embed subtitles."
fi

echo "Done. Results are in ${output_dir}."
