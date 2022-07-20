FROM python
RUN mkdir /usr/src/google_photos_takeout_helper
WORKDIR /usr/src/google_photos_takeout_helper
COPY LICENSE README.md requirements.txt setup.py /usr/src/google_photos_takeout_helper/
COPY google_photos_takeout_helper  /usr/src/google_photos_takeout_helper/google_photos_takeout_helper
COPY scripts /usr/src/google_photos_takeout_helper/google_photos_takeout_helper/scripts
COPY tests  /usr/src/google_photos_takeout_helper/google_photos_takeout_helper/tests
ENV PYTHONPATH=.
RUN ls -l
RUN python3 setup.py install
ENTRYPOINT [ "google-photos-takeout-helper" ]