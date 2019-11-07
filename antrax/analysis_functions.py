

import numpy as np
import pandas as pd


def trajectory_kinematics(df, dt=1):

    df = df.copy()
    
    x = df['x'].values
    y = df['y'].values
    dx_dt = np.gradient(x) * dt
    dy_dt = np.gradient(y) * dt
    velocity = np.array([[dx_dt[i], dy_dt[i]] for i in range(dx_dt.size)])

    ds_dt = np.sqrt(dx_dt * dx_dt + dy_dt * dy_dt)

    tangent = np.array([1 / ds_dt] * 2).transpose() * velocity

    tangent_x = tangent[:, 0]
    tangent_y = tangent[:, 1]

    deriv_tangent_x = np.gradient(tangent_x) * dt
    deriv_tangent_y = np.gradient(tangent_y) * dt

    dT_dt = np.array([[deriv_tangent_x[i], deriv_tangent_y[i]] for i in range(deriv_tangent_x.size)])

    length_dT_dt = np.sqrt(deriv_tangent_x * deriv_tangent_x + deriv_tangent_y * deriv_tangent_y)

    normal = np.array([1 / length_dT_dt] * 2).transpose() * dT_dt

    d2s_dt2 = np.gradient(ds_dt) * dt
    d2x_dt2 = np.gradient(dx_dt) * dt
    d2y_dt2 = np.gradient(dy_dt) * dt

    curvature = np.abs(d2x_dt2 * dy_dt - dx_dt * d2y_dt2) / (dx_dt * dx_dt + dy_dt * dy_dt) ** 1.5
    t_component = np.array([d2s_dt2] * 2).transpose()
    n_component = np.array([curvature * ds_dt * ds_dt] * 2).transpose()

    acceleration = t_component * tangent + n_component * normal

    df['v'] = ds_dt
    df['a'] = np.sqrt(np.sum(acceleration**2,axis=1))
    df['an'] = np.sqrt(np.sum(n_component**2,axis=1))
    df['curvature'] = curvature

    return df
