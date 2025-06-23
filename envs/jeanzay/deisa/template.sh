#!/bin/bash

#SBATCH --job-name=bench_insitu
#SBATCH --output=resTEST_N_%x_%j.out
#SBATCH --time=02:00:00
##################################################
#SBATCH -C %%${ARCH}
##################################################
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=4
##SBATCH --ntasks-per-node=1
##SBATCH --gres=gpu:4
#SBATCH --gres=gpu:1
##################################################
#SBATCH --cpus-per-task=24
##################################################
#SBATCH --hint=nomultithread
#SBATCH -A %%${IDRPROJ}@${ARCH}
#SBATCH --exclusive

PREFIX=bench_insitu
DASK_WORKER_NODES=1 ##DASK_NB_WORKERS
echo "SLURM_NNODES ${SLURM_NNODES} -----------------"
echo "DASK_WORKER_NODES ${DASK_WORKER_NODES} -----------------"
SIM_NODES=$((${SLURM_NNODES}-2-${DASK_WORKER_NODES}))
SIM_PROC=${SLURM_NNODES}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BASE_DIR=${SCRIPT_DIR}/../../..

source ${SCRIPT_DIR}/env.sh
source ${PDI_INSTALL_DIR}/share/pdi/env.sh
source ${SCRIPT_DIR}/../modules_H100.env

set -xeu

##if [ -n $GUIX_ENVIRONMENT ]; then
##  export LD_PRELOAD=$GUIX_ENVIRONMENT/lib/libz.so
##fi

print_env

type pdirun
type python3

cd ${WORKING_DIR}

run_dask () {
#  dask scheduler --scheduler-file=$SCHEFILE &
  # dask scheduler
  srun -N 1 -n 1 -c 1 -r 0 dask scheduler --scheduler-file=${SCHEFILE} >> ${PREFIX}_dask-scheduler.o &
#  sleep 5
  while ! [ -f ${SCHEFILE} ]; do
    sleep 3
  done
  sync

  echo "Starting ${DASK_NB_WORKERS} Dask workers with ${DASK_NB_THREAD_PER_WORKER} threads per worker."
#  # --nworkers sets the number of worker processes
#  # --nthreads sets the number of threads per worker process
#  dask worker --nworkers ${DASK_NB_WORKERS} --nthreads ${DASK_NB_THREAD_PER_WORKER}\
#    --local-directory ${DASK_WORKER_LOCAL_DIRECTORY}\
#    --scheduler-file=$SCHEFILE &
  # dask workers
  srun -N ${DASK_WORKER_NODES} -n ${DASK_WORKER_NODES} -c 1 -r 1 dask worker --local-directory /tmp --scheduler-file=${SCHEFILE} >> ${PREFIX}_dask-worker.o &
}


if [ "$1" = "old" ]; then
  echo "#####################"
  echo "# Running OLD Deisa #"
  echo "#####################"
  echo "Setting up Dask environement"

  source ${PYTHON_ENV}/bin/activate
  if [ -z "${VIRTUAL_ENV}" ]; then
    echo "Could not activate python environment !"
    exit 1
  fi

  run_dask
  #TODO: move client script to env/local folder
#  python3 ${SCRIPT_DIR}/../../../in-situ/fft.py $SCHEFILE &
  # insitu
  echo "BASE_DIR=${BASE_DIR}"
  srun -N 1 -n 1 -c 1 -r $(($DASK_WORKER_NODES+1)) python3 -O ${BASE_DIR}/in-situ/fft_updated.py >> ${PREFIX}_client.o &
  client_pid=$!

elif [ "$1" = "new" ]; then
  echo "#####################"
  echo "# Running NEW Deisa #"
  echo "#####################"
  echo "Setting up Dask environement"

  PYTHON_ENV="${PYTHON_ENV}_new"
  source ${PYTHON_ENV}/bin/activate
  if [ -z "${VIRTUAL_ENV}" ]; then
    echo "Could not activate python environment !"
    exit 1
  fi

  run_dask
  #TODO: move client script to env/local folder
#  python3 ${SCRIPT_DIR}/../../../in-situ/bench_deisa.py ${DASK_NB_WORKERS} $SCHEFILE &
  # insitu
  echo "BASE_DIR=${BASE_DIR}"
  srun -N 1 -n 1 -c 1 -r $(($DASK_WORKER_NODES+1)) python3 -O ${BASE_DIR}/in-situ/fft_updated.py >> ${PREFIX}_client.o &
  client_pid=$!
else
  echo "Unknown option. Accepted values are: old, new"
  exit 1
fi


cp ${SCRIPT_DIR}/deisa/io.yml ${BUILD_DIR}
cp ${SCRIPT_DIR}/deisa/setup.ini ${BUILD_DIR}
cp ${SCHEFILE} ${BUILD_DIR}

cd ${BUILD_DIR}

echo "Running simulation"
#perf record mpirun -np 2 ./main setup.ini io_deisa.yml
#mpirun -np ${MPI_NB_PROCS} ${SIMULATION_BIN} setup.ini io.yml
srun -N ${SIM_NODES} -n ${SIM_PROC} ${SIMULATION_BIN} setup.ini io.yml --kokkos-map-device-id-by=mpi_rank &

simu_pid=$!
wait $simu_pid

deactivate
pkill dask

