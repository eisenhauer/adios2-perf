#!/bin/bash

MACHINE=theta

SCALING=$1
SIZE=$2
ENGINE=$3
NWRITERS=$4

PPN=
RPPN=
if [ "$MACHINE" == "cori" ] ; then
    PPN=32
    RPPN=4
elif [ "$MACHINE" == "theta" ] ; then
    PPN=32
    RPPN=4
else
    echo "unkown machine: ${MACHINE}"
    exit
fi

if [ "$SCALING" == "strong" ] ; then
    LEN=$SIZE
elif [ "$SCALING" == "weak" ] ; then
    LEN=128
    while [ $((LEN * LEN * LEN)) -lt $((SIZE * NWRITERS)) ] ; do
        LEN=$((LEN + 32))
    done
    if [ $((LEN * LEN * LEN)) -gt $((SIZE * NWRITERS)) ] ; then
        echo "bad nwriter!"
        exit
    fi
else exit
fi

WNODES=$((NWRITERS / PPN))
NREADERS=$((NWRITERS / 32))
RNODES=$((NREADERS / RPPN))

while [ $((RPPN * RNODES)) -lt $NREADERS ] ; do
    RNODES=$((RNODES + 1))
done

SUBSTREAMS=1
if [ "$MACHINE" == "cori" ] ; then
    SUBSTREAMS=$((WNODES*2))
elif [ "$MACHINE" == "theta" ] ; then
    SUBSTREAMS=$((WNODES*4))
else
    echo "unkown machine: ${MACHINE}"
    exit
fi


NNODES=$((WNODES+RNODES))
DIR_NAME=${SCALING}_${ENGINE}_${NWRITERS}_${LEN}

if [ ! -d $DIR_NAME ] ; then
    mkdir $DIR_NAME
fi

if [ "${MACHINE}" == "theta" ] && [ ${NNODES} -lt 128 ] ; then
    NNODES=128
fi

HEADER=cfg/${MACHINE}/header
if [ ! -f ${HEADER} ] ; then
    echo "No header file file for ${MACHINE}"
    exit
fi

export NNODES
envsubst '${NNODES}' < ${HEADER} > $DIR_NAME/job.sh


JOBTEMPL=cfg/${MACHINE}/job.${ENGINE}
if [ ! -f ${JOBTEMPL} ] ; then
    echo "No job script template for ${MACHINE} and ${ENGINE}"
    exit
fi

export WNODES RNODES NWRITERS NREADERS PPN RPPN
envsubst '$WNODES $RNODES $NWRITERS $NREADERS $PPN $RPPN' < ${JOBTEMPL} >> $DIR_NAME/job.sh
chmod a+x $DIR_NAME/job.sh

export SIZE ENGINE LEN
envsubst '$SIZE $ENGINE $LEN' < cfg/cfg.json > $DIR_NAME/cfg.json

export SUBSTREAMS
envsubst '$SUBSTREAMS' < cfg/${ENGINE}.xml > $DIR_NAME/adios2.xml
