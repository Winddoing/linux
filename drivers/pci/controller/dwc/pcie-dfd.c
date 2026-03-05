// SPDX-License-Identifier: GPL-2.0

#define DEBUG
#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/of.h>
#include <linux/pci.h>
#include <linux/platform_device.h>
#include <linux/resource.h>
#include <linux/types.h>

#include "pcie-designware.h"

struct dfd_pcie {
	struct dw_pcie			*pci;
	enum dw_pcie_device_mode	mode;
};

struct dfd_pcie_of_data {
	enum dw_pcie_device_mode	mode;
};

static const struct dw_pcie_host_ops dfd_pcie_host_ops = {
};

static void dfd_pcie_ep_init(struct dw_pcie_ep *ep)
{
	struct dw_pcie *pci = to_dw_pcie_from_ep(ep);
	enum pci_barno bar;

	for (bar = 0; bar < PCI_STD_NUM_BARS; bar++)
		dw_pcie_ep_reset_bar(pci, bar);
}

static int dfd_pcie_ep_raise_irq(struct dw_pcie_ep *ep, u8 func_no,
				     unsigned int type, u16 interrupt_num)
{
	struct dw_pcie *pci = to_dw_pcie_from_ep(ep);

	switch (type) {
	case PCI_IRQ_INTX:
		return dw_pcie_ep_raise_intx_irq(ep, func_no);
	case PCI_IRQ_MSI:
		return dw_pcie_ep_raise_msi_irq(ep, func_no, interrupt_num);
	case PCI_IRQ_MSIX:
		return dw_pcie_ep_raise_msix_irq(ep, func_no, interrupt_num);
	default:
		dev_err(pci->dev, "UNKNOWN IRQ type\n");
	}

	return 0;
}

static const struct pci_epc_features dfd_pcie_epc_features = {
	.msi_capable = true,
	.msix_capable = true,
};

static const struct pci_epc_features*
dfd_pcie_get_features(struct dw_pcie_ep *ep)
{
	return &dfd_pcie_epc_features;
}

static const struct dw_pcie_ep_ops pcie_ep_ops = {
	.init = dfd_pcie_ep_init,
	.raise_irq = dfd_pcie_ep_raise_irq,
	.get_features = dfd_pcie_get_features,
};

static int dfd_add_pcie_port(struct dfd_pcie *dfd_pcie,
				 struct platform_device *pdev)
{
	struct dw_pcie *pci = dfd_pcie->pci;
	struct dw_pcie_rp *pp = &pci->pp;
	struct device *dev = &pdev->dev;
	int ret;

	dev_dbg(dev, "%s: entry.\n", __func__);

	pp->num_vectors = MAX_MSI_IRQS;
	pp->ops = &dfd_pcie_host_ops;

	ret = dw_pcie_host_init(pp);
	if (ret) {
		dev_err(dev, "Failed to initialize host\n");
		return ret;
	}

	return 0;
}

static int dfd_pcie_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct dfd_pcie *dfd_pcie;
	struct dw_pcie *pci;
	int ret;
	const struct dfd_pcie_of_data *data;
	enum dw_pcie_device_mode mode;

	dev_dbg(dev, "%s: entry.\n", __func__);

	data = of_device_get_match_data(dev);
	if (!data)
		return -EINVAL;

	mode = (enum dw_pcie_device_mode)data->mode;

	dfd_pcie = devm_kzalloc(dev, sizeof(*dfd_pcie), GFP_KERNEL);
	if (!dfd_pcie)
		return -ENOMEM;

	pci = devm_kzalloc(dev, sizeof(*pci), GFP_KERNEL);
	if (!pci)
		return -ENOMEM;

	pci->dev = dev;

	dfd_pcie->pci = pci;
	dfd_pcie->mode = mode;

	platform_set_drvdata(pdev, dfd_pcie);

	switch (dfd_pcie->mode) {
	case DW_PCIE_RC_TYPE:
		if (!IS_ENABLED(CONFIG_PCIE_DW_HOST))
			return -ENODEV;

		ret = dfd_add_pcie_port(dfd_pcie, pdev);
		break;
	case DW_PCIE_EP_TYPE:
		if (!IS_ENABLED(CONFIG_PCIE_DW_EP))
			return -ENODEV;

		pci->ep.ops = &pcie_ep_ops;
		ret = dw_pcie_ep_init(&pci->ep);
		if (ret)
			return ret;

		ret = dw_pcie_ep_init_registers(&pci->ep);
		if (ret) {
			dev_err(dev, "Failed to initialize DWC endpoint registers\n");
			dw_pcie_ep_deinit(&pci->ep);
		}

		pci_epc_init_notify(pci->ep.epc);

		break;
	default:
		dev_err(dev, "INVALID device type %d\n", dfd_pcie->mode);
		ret = -EINVAL;
		break;
	}

	return ret;
}

static const struct dfd_pcie_of_data dfd_pcie_rc_of_data = {
	.mode = DW_PCIE_RC_TYPE,
};

static const struct dfd_pcie_of_data dfd_pcie_ep_of_data = {
	.mode = DW_PCIE_EP_TYPE,
};

static const struct of_device_id dfd_pcie_of_match[] = {
	{
		.compatible = "dfd,dw-pcie",
		.data = &dfd_pcie_rc_of_data,
	},
	{
		.compatible = "dfd,dw-pcie-ep",
		.data = &dfd_pcie_ep_of_data,
	},
	{},
};

static struct platform_driver dfd_pcie_driver = {
	.driver = {
		.name	= "dw-pcie",
		.of_match_table = dfd_pcie_of_match,
		.suppress_bind_attrs = true,
	},
	.probe = dfd_pcie_probe,
};
builtin_platform_driver(dfd_pcie_driver);
