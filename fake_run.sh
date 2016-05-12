#!/usr/bin/env bash

i="0"

while [ $i -lt 5 ]
do
    echo 'main_channel_link: add main channel client'
    sleep 1

    echo 'main_channel_client_on_disconnect: rcc=0x562cead91100'
    sleep 1

    let i=i+1
done