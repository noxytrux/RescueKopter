//
//  Skybox.metal
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#include "ShaderCommon.h"

vertex VertexOutput skyboxVertex(device Vertex *vertexData [[ buffer(0) ]],
                                 constant modelMatrices *matrices [[ buffer(1) ]],
                                 constant sunData &sunInfo [[ buffer(2) ]],
                                 uint vid [[vertex_id]])
{
    VertexOutput outVertex;
    Vertex vData = vertexData[vid];
    
    float4 position = float4(vData.position,1.0);
    
    outVertex.v_position = matrices->projectionMatrix * matrices->modelViewMatrix * position;
    
    outVertex.v_sun = position.xyz;
    outVertex.v_sunColor = sunInfo.sunColor;
    
    return outVertex;
};

fragment float4 skyboxFragment(VertexOutput inFrag [[stage_in]],
                               texturecube<float> diffuseTexture [[ texture(0) ]])
{
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    
    float4 outColor = diffuseTexture.sample(linear_sampler, inFrag.v_sun);
    
    return float4( float3( inFrag.v_sunColor * outColor.rgb ), outColor.a);
};

