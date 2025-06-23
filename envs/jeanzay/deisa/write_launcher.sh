#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/env.sh
GENERATED_LAUNCHER=${SCRIPT_DIR}/updated_launcher.sh
cp ${SCRIPT_DIR}/template.sh ${GENERATED_LAUNCHER}

if [ "${GPU_ARCH}" == "" ]; then
    echo "Error : GPU_ARCH is not given."
    exit 1
fi

if [ "${GPU_ARCH}" == "V100" ]; then

    sed -i "s/^#SBATCH -A.*$/#SBATCH -A ${IDRPROJ}@v100/g" ${GENERATED_LAUNCHER}
    if [ "${GPU_MEM}" == "16G" ]; then
        sed -i "s/^#SBATCH -C.*$/#SBATCH -C v100\-16g/g" ${GENERATED_LAUNCHER}
    elif [ "${GPU_MEM}" == "32G" ]; then
        sed -i "s/^#SBATCH -C.*$/#SBATCH -C v100\-32g/g" ${GENERATED_LAUNCHER}
    fi
    sed -i "s|^#SBATCH --cpus-per-task=.*$|#SBATCH --cpus-per-task=10|g" ${GENERATED_LAUNCHER}

elif [ "${GPU_ARCH}" = "A100" ]; then

    sed -i "s/^#SBATCH -A.*$/#SBATCH -A ${IDRPROJ}@a100/g" ${GENERATED_LAUNCHER}
    sed -i "s/^#SBATCH -C.*$/#SBATCH -C a100/g" ${GENERATED_LAUNCHER}
    sed -i "s|^#SBATCH --cpus-per-task=.*$|#SBATCH --cpus-per-task=8|g" ${GENERATED_LAUNCHER}

elif [ "${GPU_ARCH}" = "H100" ]; then

    sed -i "s/^#SBATCH -A.*$/#SBATCH -A ${IDRPROJ}@h100/g" ${GENERATED_LAUNCHER}
    sed -i "s/^#SBATCH -C.*$/#SBATCH -C h100/g" ${GENERATED_LAUNCHER}
    sed -i "s|^#SBATCH --cpus-per-task=.*$|#SBATCH --cpus-per-task=24|g" ${GENERATED_LAUNCHER}

fi

sed -i "s|^SCRIPT_DIR=.*$|SCRIPT_DIR=${SCRIPT_DIR}|g" ${GENERATED_LAUNCHER}
