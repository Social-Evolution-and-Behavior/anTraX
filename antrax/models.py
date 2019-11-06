
from os.path import isfile, isdir

import tensorflow as tf

from tensorflow.keras.models import Sequential, model_from_json, model_from_yaml
from tensorflow.keras.layers import Dense, Dropout, Activation, Flatten
from tensorflow.keras.layers import Convolution2D, MaxPooling2D,BatchNormalization


def new_model(prmtrs):

    if isfile(prmtrs['modeltype']) and prmtrs['modeltype'][-4:] == 'json':

        json_file = open(prmtrs['modeltype'], 'r')
        loaded_model_json = json_file.read()
        json_file.close()
        model = model_from_json(loaded_model_json)

    elif isfile(prmtrs['modeltype']) and prmtrs['modeltype'][-4:] == 'yaml':

        yaml_file = open(prmtrs['modeltype'], 'r')
        loaded_model_yaml = yaml_file.read()
        yaml_file.close()
        model = model_from_yaml(loaded_model_yaml)

    elif prmtrs['modeltype'] == 'MobileNetV2':

        model = MobileNetV2(prmtrs['nclasses'], prmtrs['target_size'])

    elif prmtrs['modeltype'] == 'small':

        model = small(prmtrs['nclasses'], prmtrs['target_size'])

    else:

        print('Unknown or unimplemented model type')
        return None

    print('new_model: target size is ' + str(prmtrs['target_size']) + ', scale factor is ' + str(prmtrs['scale']))

    return model


def MobileNetV2(nclasses, target_size):

    base_model = tf.keras.applications.MobileNetV2(input_shape=(target_size, target_size, 3),
                                                   include_top=False,
                                                   weights='imagenet')

    base_model.trainable = False

    global_average_layer = tf.keras.layers.GlobalAveragePooling2D()
    prediction_layer = tf.keras.layers.Dense(nclasses, activation='softmax')

    model = tf.keras.Sequential([
        base_model,
        global_average_layer,
        prediction_layer
    ])

    return model


def medium(nClasses, target_size):

    model = Sequential()
    model.add(Convolution2D(128, (3, 3), activation='relu', input_shape=(target_size, target_size, 3)))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    # model.add(Convolution2D(64, (3, 3), activation='relu'))
    model.add(Convolution2D(256, (3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    # model.add(Convolution2D(64, (3, 3), activation='relu'))
    model.add(Convolution2D(512, (3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    model.add(Flatten())
    model.add(BatchNormalization())
    # model.add(Dense(64, activation='softmax'))
    model.add(Dropout(0.25))
    model.add(Dense(nClasses, activation='softmax'))

    return model


def small(nClasses, target_size):

    model = Sequential()
    model.add(Convolution2D(64, (3, 3), activation='relu', input_shape=(target_size, target_size, 3)))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    # model.add(Convolution2D(64, (3, 3), activation='relu'))
    model.add(Convolution2D(128, (3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    # model.add(Convolution2D(64, (3, 3), activation='relu'))
    model.add(Convolution2D(256, (3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(BatchNormalization())
    model.add(Dropout(0.25))

    model.add(Flatten())
    model.add(BatchNormalization())
    # model.add(Dense(64, activation='softmax'))
    model.add(Dropout(0.25))
    model.add(Dense(nClasses, activation='softmax'))

    return model
