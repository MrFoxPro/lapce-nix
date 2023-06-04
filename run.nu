#!/usr/bin/nu
let target = /home/foxpro/.local/share/lapce-stable/plugins/mrfoxpro.lapce-nil

let files = [ 
    ./bin/lapce-nil.wasm 
    ./volt.toml
    ./icon.png
    ./README.md
]
rm -r $target
mkdir $target

for $file in $files {
    # ln -sfr $file $target
    cp $file $target
}
exec lapce