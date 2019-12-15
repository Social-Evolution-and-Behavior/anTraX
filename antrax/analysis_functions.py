

import numpy as np
import pandas as pd

idx = pd.IndexSlice

def test():
    
    print('tested')

def wavelet_expansion(x, n=25, maxscale=50):

    import pywt

    scales = np.geomspace(1, maxscale, num=n, endpoint=True)

    x = (x - np.nanmean(x, axis=0)) / np.nanstd(x, axis=0)
    x, _ = pywt.cwt(x, scales=scales, wavelet='morl', axis=0)
    x = np.moveaxis(x, [0, 1, 2], [2, 0, 1])
    x = np.reshape(x, (x.shape[0], x.shape[1] * x.shape[2]))

    return x


def behavioral_features(ad, n=25, features=['velocity', 'acceleration', 'normal_acceleration', 'r_ant_angle', 'l_ant_angle']):

    import pywt
    
    data = ad.data.loc[:,idx[:,features]].copy()
    
    df = []
    
    for ant in ad.antlist:
            
        x = data.loc[:,idx[ant,:]].values
        x = wavelet_expansion(x, n=n, maxscale=50)
        mi = pd.MultiIndex.from_tuples([(ant,i) for i in range(x.shape[1])],names=['ant','feature'])
        df.append(pd.DataFrame(x, index=data.index, columns=mi))
    
    df = pd.concat(df, axis=1)
    df = df.stack(level='ant', dropna=False)
    df = df.dropna()
        
    return df

def postural_features(ad, n=25, bodyparts=['Head','L_ant_root','R_ant_root','L_ant_tip','R_ant_tip','Neck','ThxAbd','Tail'], refpart='Neck'):
        
        import pywt
        
        idx = pd.IndexSlice
        
        likelihhod_threshold = 0.99
        
        cols = [bp+'_likelihood' for bp in bodyparts]
        likelihood =  ad.data.loc[:,idx[:,cols]]
        likelihood = likelihood.stack(level='ant', dropna=False)
        likelihood = likelihood.min(axis=1)
        likelihood = likelihood.unstack()
        likelihood[likelihood<likelihhod_threshold] = np.nan
        
        
        cols = sorted([bp+'_x' for bp in bodyparts] + [bp+'_y' for bp in bodyparts])
        data = ad.data.loc[:,idx[:,cols]].copy()

        refx = data.loc[:,idx[:,refpart+'_x']].copy()
        refy = data.loc[:,idx[:,refpart+'_y']].copy()
        
        data = data.drop(refpart+'_x', axis=1, level=1)
        data = data.drop(refpart+'_y', axis=1, level=1)
        
        bodyparts.remove(refpart)
        
        refx.shape
                
        for bp in bodyparts:
            data.loc[:,idx[:,bp+'_x']] = data.loc[:,idx[:,bp+'_x']] * likelihood
            data.loc[:,idx[:,bp+'_y']] = data.loc[:,idx[:,bp+'_y']] * likelihood
            data.loc[:,idx[:,bp+'_x']] = data.loc[:,idx[:,bp+'_x']] - refx.values
            data.loc[:,idx[:,bp+'_y']] = data.loc[:,idx[:,bp+'_y']] - refy.values
                
                
        df = []
        
        for ant in ad.antlist:
            x = data.loc[:,idx[ant,:]].values
            x = wavelet_expansion(x, n=n, maxscale=50)
            mi = pd.MultiIndex.from_tuples([(ant,i) for i in range(x.shape[1])],names=['ant','feature'])
            df.append(pd.DataFrame(x, index=data.index, columns=mi))
        
        df = pd.concat(df, axis=1)
        df = df.stack(level='ant', dropna=False)
        df = df.dropna()
        
        return df


def tsne_mapping(df, trainsetsize=1000):
    
    import sklearn
    
    print('Preparing data')
    
    # if dataframe with ants, cast into long format
    df = df.stack(level='ant', dropna=False)
    
    # filter out nans
    df1 = df.dropna()
    
    # sample training set
    df1 = df1.sample(n=trainsetsize, axis=0)
    
    # find mapping
    print('Training tsne')
    tsne = sklearn.manifold.TSNE(n_components=2, perplexity=30)
    tsne.fit(df1.values)
    
    # project
    print('Projecting')
    mi = pd.MultiIndex.from_tuples([('x','y')])
    df = pd.DataFrame(tsne.transform(df.values), index=df.index, columns=mi)
    
    # put ant table back together
    df = df.unstack(level='ant')
    print('Done')
    
    return df, tsne



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
