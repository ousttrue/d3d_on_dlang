module d3d11manager;
import derelict.windows.kits_8_1.d3d11;
import derelict.windows.kits_8_1.d3dcompiler;
import std.file;
import core.sys.windows.windef;
import core.sys.windows.windows: MessageBoxA, MB_OK;
import core.sys.windows.com;
import dvecmath.dvecmath;


struct ComPtr(T)
{
    T ptr;
    alias ptr this;
    this(this) { if (ptr) ptr.AddRef(); } // post-blit
    ~this() { if(ptr)ptr.Release(); } // destructor
    bool opCast(V)() const if (is(V==bool))
    {
        return ptr ? true : false;
    }
}


HRESULT D3DCompileFromFile(
        in string pFileName,
        in D3D_SHADER_MACRO *pDefines,
        in void* pInclude,
        in string pEntrypoint,
        in string pTarget,
        UINT Flags1,
        UINT Flags2,
        ID3DBlob *ppCode,
        ID3DBlob *ppErrorMsgs
        )
{
    auto bytes = cast(ubyte[])read(pFileName);
    return D3DCompile(bytes.ptr, bytes.length
            , pFileName.ptr
            , pDefines
            , pInclude
            , pEntrypoint.ptr
            , pTarget.ptr
            , Flags1
            , Flags2
            , ppCode
            , ppErrorMsgs);
}


HRESULT CompileShaderFromFile
(
 in string szFileName,
 in string szEntryPoint,
 in string szShaderModel,
 ID3DBlob *ppBlobOut
)
{
    // コンパイルフラグ.
    auto dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;
    dwShaderFlags |= D3DCOMPILE_DEBUG;
    dwShaderFlags |= D3DCOMPILE_OPTIMIZATION_LEVEL3;


    // ファイルからシェーダをコンパイル.
    ComPtr!(ID3DBlob) pErrorBlob;
    auto hr = D3DCompileFromFile(
							szFileName,
							null,
							cast(void*)D3D_COMPILE_STANDARD_FILE_INCLUDE,
							szEntryPoint,
							szShaderModel,
							dwShaderFlags,
							0,
							ppBlobOut,
							&pErrorBlob.ptr
							);

    // エラーチェック.
    if ( FAILED( hr ) )
    {
        // エラーメッセージを出力.
        if ( pErrorBlob ){
			auto msg=cast(char*)pErrorBlob.GetBufferPointer();
			//int a=0;
			MessageBoxA(null, msg, "compile error", MB_OK);
		}
        //{ OutputDebugStringA( ; }
    }

    // リターンコードを返却.
    return hr;
}


class ConstantBuffer(T)
{
	ComPtr!ID3D11Buffer m_pBuffer;

public:
	T Buffer;

	bool Initialize(ref ComPtr!ID3D11Device pDevice)
	{
		D3D11_BUFFER_DESC desc = { 0 };

        desc.ByteWidth = T.sizeof;
        desc.Usage = D3D11_USAGE.DEFAULT;
        desc.BindFlags = D3D11_BIND.CONSTANT_BUFFER;

		auto hr = pDevice.CreateBuffer(&desc, null, &m_pBuffer.ptr);
		if (FAILED(hr)){
			return false;
		}

		return true;
	}

	void Update(ref ComPtr!(ID3D11DeviceContext) pDeviceContext)
	{
		pDeviceContext.UpdateSubresource(m_pBuffer.ptr, 0, null, &Buffer, 0, 0);
	}

	void SetPipeline(ref ComPtr!ID3D11DeviceContext pDeviceContext)
	{
        auto buffers=[ m_pBuffer.ptr ];
		pDeviceContext.VSSetConstantBuffers(0, cast(uint)buffers.length, buffers.ptr);
	}
}


class Shader
{
    ComPtr!(ID3D11VertexShader) m_pVsh;
    ComPtr!(ID3D11PixelShader) m_pPsh;
    ComPtr!(ID3D11InputLayout) m_pInputLayout;

    struct TriangleVariables
    {
        mat4 Model;
    };
    ConstantBuffer!(TriangleVariables) m_constant=new ConstantBuffer!(TriangleVariables)();
	ConstantBuffer!(TriangleVariables) GetConstantBuffer()
	{
		return m_constant;
	}

    public bool Initialize(ComPtr!(ID3D11Device) pDevice, in string shaderFile)
    {
        if(!createShaders(pDevice, shaderFile, "VS", "PS")){
            return false;
        }

		if (!m_constant.Initialize(pDevice)){
			return false;
		}

        return true;
    }

    public void Setup(ComPtr!(ID3D11DeviceContext) pDeviceContext)
    {
        // Shaderのセットアップ
        pDeviceContext.VSSetShader(m_pVsh.ptr, null, 0);
        pDeviceContext.PSSetShader(m_pPsh.ptr, null, 0);

        // ILのセット
        pDeviceContext.IASetInputLayout(m_pInputLayout);

		// 定数バッファの更新
		m_constant.Update(pDeviceContext);
		m_constant.SetPipeline(pDeviceContext);
    }

    private bool createShaders(ref ComPtr!(ID3D11Device) pDevice
		, in string shaderFile, in string vsFunc, in string psFunc)
    {
        // vertex shader
        ComPtr!(ID3DBlob) vblob;
        HRESULT hr = CompileShaderFromFile(shaderFile, vsFunc, "vs_4_0_level_9_1", &vblob.ptr);
        if (FAILED(hr))
            return false;
        hr = pDevice.CreateVertexShader(vblob.GetBufferPointer(), vblob.GetBufferSize(), null, &m_pVsh.ptr);
        if (FAILED(hr))
            return false;

        // pixel shader
        ComPtr!(ID3DBlob) pblob;
        hr = CompileShaderFromFile(shaderFile, psFunc, "ps_4_0_level_9_1", &pblob.ptr);
        if (FAILED(hr))
            return false;
        hr = pDevice.CreatePixelShader(pblob.GetBufferPointer(), pblob.GetBufferSize(), null, &m_pPsh.ptr);
        if (FAILED(hr))
            return false;

        // Create InputLayout
        auto vbElement =
        [
            D3D11_INPUT_ELEMENT_DESC("POSITION", 0, DXGI_FORMAT.R32G32B32A32_FLOAT
									 , 0, 0, D3D11_INPUT.PER_VERTEX_DATA, 0),
            D3D11_INPUT_ELEMENT_DESC("COLOR", 0, DXGI_FORMAT.R32G32B32A32_FLOAT
									 , 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT.PER_VERTEX_DATA, 0)
        ];

        hr = pDevice.CreateInputLayout(vbElement.ptr, cast(uint)vbElement.length
                , vblob.GetBufferPointer(), vblob.GetBufferSize(), &m_pInputLayout.ptr);
        if (FAILED(hr))
            return false;

        return true;
    }
}


// input-assembler
struct Vec4
{
	float x;
	float y;
	float z;
	float w;
};
struct Vertex
{
	Vec4 pos;
	Vec4 color;
};


class InputAssemblerSource
{
    ComPtr!(ID3D11Buffer) m_pVertexBuf;
    ComPtr!(ID3D11Buffer) m_pIndexBuf;
public:

    bool Initialize(ComPtr!(ID3D11Device) pDevice)
    {
        if(!createVB(pDevice)){
            return false;
        }
        if(!createIB(pDevice)){
            return false;
        }
        return true;
    }

    void Draw(ComPtr!(ID3D11DeviceContext) pDeviceContext)
    {
        // VBのセット
        auto pBufferTbl = [ m_pVertexBuf.ptr ];
        auto SizeTbl = [ cast(uint)Vertex.sizeof ];
        UINT[] OffsetTbl = [ 0 ];
        pDeviceContext.IASetVertexBuffers(0, cast(uint)pBufferTbl.length, pBufferTbl.ptr, SizeTbl.ptr, OffsetTbl.ptr);
        // IBのセット
        pDeviceContext.IASetIndexBuffer(m_pIndexBuf, DXGI_FORMAT.R32_UINT, 0);
        // プリミティブタイプのセット
        pDeviceContext.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY.D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);

        pDeviceContext.DrawIndexed(3 // index count
									, 0, 0);
    }

private:
    bool createVB(ComPtr!(ID3D11Device) pDevice)
    {
        // Create VB
        Vertex[3] pVertices =
        [
			Vertex(Vec4(0.0f, 0.0f, 0.0f, 1.0f), Vec4(1.0f, 0.0f, 0.0f, 1.0f)),
			Vertex(Vec4(0.5f, 0.5f, 0.0f, 1.0f), Vec4(0.0f, 1.0f, 0.0f, 1.0f)),
			Vertex(Vec4(0.5f, -0.5f, 0.0f, 1.0f), Vec4(0.0f, 0.0f, 1.0f, 1.0f)),
        ];

        D3D11_BUFFER_DESC vdesc;
        vdesc.ByteWidth = pVertices.sizeof;
        vdesc.Usage = D3D11_USAGE.DEFAULT;
        vdesc.BindFlags = D3D11_BIND.VERTEX_BUFFER;
        vdesc.CPUAccessFlags = 0;

        D3D11_SUBRESOURCE_DATA vertexData;
        vertexData.pSysMem = pVertices.ptr;

        HRESULT hr = pDevice.CreateBuffer(&vdesc, &vertexData, &m_pVertexBuf.ptr);
        if (FAILED(hr)){
            return false;
        }

        return true;
    }

	bool createIB(ComPtr!(ID3D11Device) pDevice)
    {
        uint[3] pIndices = [0, 1, 2];

        D3D11_BUFFER_DESC idesc;
        idesc.ByteWidth = pIndices.sizeof;
        idesc.Usage = D3D11_USAGE.DEFAULT;
        idesc.BindFlags = D3D11_BIND.INDEX_BUFFER;
        idesc.CPUAccessFlags = 0;

		D3D11_SUBRESOURCE_DATA indexData;
		indexData.pSysMem = pIndices.ptr;

        HRESULT hr = pDevice.CreateBuffer(&idesc, &indexData, &m_pIndexBuf.ptr);
		if (FAILED(hr)){
			return false;
		}

        return true;
    }
}


class RenderTarget
{
    ComPtr!(ID3D11RenderTargetView) m_pRenderTargetView;
	D3D11_TEXTURE2D_DESC m_colorDesc;

public:
    bool IsInitialized()const{ return m_pRenderTargetView ? true : false; }

    bool Initialize(ComPtr!(ID3D11Device) pDevice, ID3D11Texture2D pTexture)
    {
		pTexture.GetDesc(&m_colorDesc);

        // RenderTargetViewの作成
        HRESULT hr = pDevice.CreateRenderTargetView(pTexture, null, &m_pRenderTargetView.ptr);
        if (FAILED(hr)){
            return false;
        }

        return true;
    }

    void SetAndClear(ComPtr!(ID3D11DeviceContext) pDeviceContext)
    {
        // Output-Merger stage
		auto renderTargets=[ m_pRenderTargetView.ptr ];
        pDeviceContext.OMSetRenderTargets(cast(uint)renderTargets.length, renderTargets.ptr, null);

        if(m_pRenderTargetView){
            // clear
            auto clearColor = [ 0.0f, 0.0f, 1.0f, 0.0f ];
            pDeviceContext.ClearRenderTargetView(m_pRenderTargetView, clearColor.ptr);

            // Rasterizer stage
            D3D11_VIEWPORT vp;
            vp.Width = cast(float)m_colorDesc.Width;
            vp.Height = cast(float)m_colorDesc.Height;
            vp.MinDepth = 0.0f;
            vp.MaxDepth = 1.0f;
            vp.TopLeftX = 0;
            vp.TopLeftY = 0;
            pDeviceContext.RSSetViewports(1, &vp);
        }
    }
}

GUID toGUID(immutable UUID uuid)
{
	ubyte[8] data=uuid.data[8..$];
	return GUID(
				uuid.data[0] << 24
				|uuid.data[1] << 16
				|uuid.data[2] << 8
				|uuid.data[3],

				uuid.data[4] << 8
				|uuid.data[5],

				uuid.data[6] << 8
				|uuid.data[7],

				data
				);
}


struct D3D11Manager
{
	ComPtr!(ID3D11Device) m_pDevice;
	ComPtr!(ID3D11DeviceContext) m_pDeviceContext;
	ComPtr!(IDXGISwapChain) m_pSwapChain;

    Shader m_shader= new Shader();
	InputAssemblerSource m_IASource=new InputAssemblerSource();

	RenderTarget m_renderTarget=new RenderTarget();

	bool Initialize(HWND hWnd, in string shaderFile)
	{
		auto dtype = D3D_DRIVER_TYPE.HARDWARE;
		UINT flags = 0;
		auto featureLevels = [
			D3D_FEATURE_LEVEL._11_0,
			D3D_FEATURE_LEVEL._10_1,
			D3D_FEATURE_LEVEL._10_0,
			D3D_FEATURE_LEVEL._9_3,
			D3D_FEATURE_LEVEL._9_2,
			D3D_FEATURE_LEVEL._9_1,
		];

		//UINT numFeatureLevels = sizeof(featureLevels) / sizeof(D3D_FEATURE_LEVEL);
		auto sdkVersion = D3D11_SDK_VERSION;
		D3D_FEATURE_LEVEL validFeatureLevel;

		DXGI_SWAP_CHAIN_DESC scDesc;
		scDesc.BufferCount = 1;
		scDesc.BufferDesc.Width = 0;
		scDesc.BufferDesc.Height = 0;
		scDesc.BufferDesc.Format = DXGI_FORMAT.R8G8B8A8_UNORM_SRGB;
		scDesc.BufferDesc.RefreshRate.Numerator = 60;
		scDesc.BufferDesc.RefreshRate.Denominator = 1;
		scDesc.BufferUsage = DXGI_USAGE.RENDER_TARGET_OUTPUT;
		scDesc.OutputWindow = hWnd;
		scDesc.SampleDesc.Count = 1;
		scDesc.SampleDesc.Quality = 0;
		scDesc.Windowed = TRUE;

		HRESULT hr = D3D11CreateDeviceAndSwapChain(
												   IDXGIAdapter.init,
												   dtype,
												   null,
												   flags,
												   featureLevels.ptr,
												   cast(uint)featureLevels.length,
												   sdkVersion,
												   &scDesc,
												   &m_pSwapChain.ptr,
												   &m_pDevice.ptr,
												   &validFeatureLevel,
												   &m_pDeviceContext.ptr
												   );
		if (FAILED(hr)){
			return false;
		}

		if(!m_shader.Initialize(m_pDevice, shaderFile)){
			return false;
		}

		if(!m_IASource.Initialize(m_pDevice)){
			return false;
		}

		return true;
	}

	void Resize(int w, int h)
	{
		if (!m_pDeviceContext){
			return;
		}
		if(w==0 || h==0)return;

		// clear render target
		m_renderTarget=new RenderTarget();
		m_renderTarget.SetAndClear(m_pDeviceContext);
		// resize swapchain
		DXGI_SWAP_CHAIN_DESC desc;
		m_pSwapChain.GetDesc(&desc);
		m_pSwapChain.ResizeBuffers(desc.BufferCount,
									0, 0,	// ClientRect を参照する
									desc.BufferDesc.Format,
									0 // flags
									);
	}

	immutable GUID IID_ID3D11Texture2D           = {0x6f15aaf2, 0xd208, 0x4e89, [0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c]};

	void Render()
	{
		if(!m_renderTarget.IsInitialized()){

			// バックバッファの取得
			ID3D11Texture2D pBackBuffer;
			GUID guid=pBackBuffer.uuidof.toGUID;
			auto data1=guid.Data1;
			auto data2=guid.Data2;
			auto data3=guid.Data3;
			auto data4=guid.Data4;
			m_pSwapChain.GetBuffer(0, 
									//cast(GUID*)ID3D11Texture2D.uuidof.data.ptr,
								    &guid,
								    //&IID_ID3D11Texture2D,
									cast(void**)&pBackBuffer);

			if(!m_renderTarget.Initialize(m_pDevice, pBackBuffer)){
				return;
			}
		}
		m_renderTarget.SetAndClear(m_pDeviceContext);

		// update
		{
			//auto m = DirectX::XMMatrixIdentity();
			static angleRadians = radians(0);
			const DELTA = radians.fromDegree(0.1f);
			angleRadians += DELTA;
			auto m = mat4.zAxisRotation(angleRadians);
            // shader
            m_shader.GetConstantBuffer().Buffer.Model=m;
		}

		m_shader.Setup(m_pDeviceContext);

		// 描画
		{
			// vertex buffer(Input-Assembler stage)
			m_IASource.Draw(m_pDeviceContext);
		}

		// render targetへの描画
		//m_pDeviceContext.Flush();

		// 描画済みのrender targetをモニタに出力
		m_pSwapChain.Present(0, 0);
	}
};

shared static this() {
    // derelict
    D3D11.load();
	D3DCompiler.load();
}
