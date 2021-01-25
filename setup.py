import pathlib
import setuptools

HERE = pathlib.Path(__file__).parent

README = (HERE/"README.md").read_text()

setuptools.setup(
    name="google-photos-takeout-helper",
    version="2.1.0b1",
    description="Script that organizes the Google Photos Takeout archive into one big chronological folder",
    long_description=README,
    long_description_content_type='text/markdown',
    url='https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/',
    author='TheLastGimbus',
    author_email='mateusz.soszynski@tuta.io',
    license='Apache',
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        'License :: OSI Approved :: Apache Software License',
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: End Users/Desktop',
        'Topic :: Multimedia :: Graphics'
    ],
    python_requires='>=3.6',
    install_requires=(HERE/'requirements.txt').read_text().split('\n'),
    entry_points={
        'console_scripts': [
            'google-photos-takeout-helper=google_photos_takeout_helper.__main__:main'
        ]
    }
)
