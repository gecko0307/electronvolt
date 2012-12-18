module photon.graphics.shader;

private
{
    import photon.core.modifier;
}

interface Shader: Modifier
{
    @property bool supported();
    void bind(double delta);
    void unbind();
    void free();
}