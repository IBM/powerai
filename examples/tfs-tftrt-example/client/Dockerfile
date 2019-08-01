FROM ibmcom/powerai:1.6.1-tensorflow-ubuntu18.04-py3

ARG CLIENT_USER="clientid"
RUN useradd --create-home --shell /bin/bash --comment "Tensorflow-serving user" ${CLIENT_USER}

RUN echo "source ${CONDA_INSTALL_DIR}/etc/profile.d/conda.sh" >> /home/${CLIENT_USER}/.bashrc
RUN echo "conda activate base" >> /home/${CLIENT_USER}/.bashrc

RUN ${CONDA_INSTALL_DIR}/bin/conda install pillow -y

USER ${CLIENT_USER}
RUN mkdir /home/${CLIENT_USER}/example
COPY ./code/resnet_v1_50_inference_client_batch_dataset.py /home/${CLIENT_USER}/example
RUN  mkdir -p /home/${CLIENT_USER}/example/testdata

USER root
