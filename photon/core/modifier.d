module photon.core.modifier;

interface Modifier
{
    void bind(double delta);
    void unbind();
    void free();
}
