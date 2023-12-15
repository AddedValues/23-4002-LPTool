import os
import dash
from dash import html
from dash import dcc
import dash_bootstrap_components as dbc
import pandas as pd
import plotly.express as px



# load data
os.chdir(r'C:\GitHub\23-4002-LPTool\Python playground')
df = pd.read_csv('train.csv')
# make plot
fig = px.histogram(df, x='Age')
# initialize app
app = dash.Dash(__name__, external_stylesheets=[dbc.themes.UNITED])
# set app layout
app.layout = html.Div(children=[
    html.H1('Test Dash App', style={'textAlign':'center'}),
    html.Br(),
    dcc.Dropdown(
        options=[{'label': i, 'value': i} for i in df.columns],
        value='Age',
        id='dropdown',
        style={"width": "50%", "offset":1,},
        clearable=False,
    ),
    dcc.Graph(id='histogram', figure=fig)
])
if __name__ == "__main__":
    # app.run_server(debug=True)S
    app.run_server(debug=False)

#%%
    
import os
import plotly.graph_objects as go

# Create random data with numpy
import numpy as np
np.random.seed(1)

N = 100
random_x = np.linspace(0, 1, N)
random_y0 = np.random.randn(N) + 5
random_y1 = np.random.randn(N)
random_y2 = np.random.randn(N) - 5

fig = go.Figure()

# Add traces
fig.add_trace(go.Scatter(x=random_x, y=random_y0,
                    mode='markers',
                    name='markers'))
fig.add_trace(go.Scatter(x=random_x, y=random_y1,
                    mode='lines+markers',
                    name='lines+markers'))
fig.add_trace(go.Scatter(x=random_x, y=random_y2,
                    mode='lines',
                    name='lines'))

fig.show()
# %%
