using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshRenderer))]
public class SwapController : MonoBehaviour
{
    [SerializeField] private Material defaultMaterial;
    [SerializeField] private Material disneyBrdfMaterial;
    private List<Material> _materials;
    private int _curMaterial = 0;
    private MeshRenderer _meshRenderer;

    void Start() {
        _meshRenderer = GetComponent<MeshRenderer>();
        _materials = new List<Material> {
            disneyBrdfMaterial,
            defaultMaterial
        };
        _meshRenderer.material = _materials[_curMaterial];
    }
    
    void Update() {
        if (Input.GetKeyUp(KeyCode.S)) {
            SwapMaterial();
        }
    }

    private void SwapMaterial() {
        _curMaterial++;
        if (_curMaterial >= _materials.Count)
        {
            _curMaterial = 0;
        }
        _meshRenderer.material = _materials[_curMaterial];
    }
}
