gcc -std=c++11 `pkg-config --cflags opencv` `pkg-config --libs opencv` gstreamer_view.cpp -o gstreamer_view -lstdc++ -lopencv_core -lopencv_highgui -lopencv_videoio
