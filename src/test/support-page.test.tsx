import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, it, expect } from "vitest";
import SupportPage from "../pages/SupportPage";

describe("SupportPage", () => {
  it("renders the customer support page with Telegram access", () => {
    render(
      <MemoryRouter>
        <SupportPage />
      </MemoryRouter>,
    );

    expect(screen.getByText("Service client")).toBeInTheDocument();
    expect(
      screen.getByText("Rejoindre le groupe Telegram"),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: /Rejoindre le groupe Telegram/i }),
    ).toHaveAttribute("href", "https://t.me/+S0z1QeF2z4o4OGI8");
  });
});
